const assets = "/scoutvision/assets/";
const scriptLoads = new Map();
export const detectorNames = {
  speedway: "Speedway RF-DETR Large",
  "speedway-yolo": "Speedway YOLO",
  highlander: "Highlander YOLO",
};
const yoloAssets = {
  highlander:{prefix:"highlander-yolo-v2", size:480},
  "speedway-yolo":{prefix:"speedway-yolo-480-v1", size:480},
};
export const isYolo = choice => Object.hasOwn(yoloAssets, choice);

export function loadScript(name) {
  if (!scriptLoads.has(name)) {
    scriptLoads.set(name, new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = assets + name;
      script.onload = () => resolve(globalThis.ort);
      script.onerror = () => { scriptLoads.delete(name); reject(new Error("Could not load the browser model runtime.")); };
      document.head.append(script);
    }));
  }
  return scriptLoads.get(name);
}

export function overlap(a, b) {
  const width = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
  const height = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
  const intersection = width * height;
  return intersection / (a.w * a.h + b.w * b.h - intersection || 1);
}

export function suppress(boxes, limit = 12) {
  const selected = [];
  for (const box of [...boxes].sort((a, b) => b.score - a.score)) {
    if (selected.some(previous => overlap(box, previous) > .45)) continue;
    selected.push(box);
    if (selected.length === limit) break;
  }
  return selected;
}

export async function downloadModel(prefix, count) {
  const parts = await Promise.all(Array.from({length: count}, async (_, index) => {
    const response = await fetch(assets + `${prefix}-${index + 1}.bin`);
    if (!response.ok) throw new Error("Could not load the selected robot detector. Try again.");
    return new Uint8Array(await response.arrayBuffer());
  }));
  const bytes = new Uint8Array(parts.reduce((total, part) => total + part.length, 0));
  let offset = 0;
  for (const part of parts) {
    bytes.set(part, offset);
    offset += part.length;
  }
  return bytes;
}

async function runtime(name, bytes) {
  const ort = await loadScript(name === "webgl" ? "ort.webgl.min.js" : "ort.wasm.min.js");
  ort.env.logLevel = "error";
  if (name === "webgl") ort.env.webgl.pack = false;
  if (name === "wasm") {
    ort.env.wasm.wasmPaths = assets;
    ort.env.wasm.numThreads = 1;
  }
  const session = await ort.InferenceSession.create(bytes, {executionProviders: [name]});
  return {ort, session, name};
}

let webgpuLibrary;
export async function webgpuRuntime(bytes, size) {
  webgpuLibrary ||= (async () => {
    const adapter = await navigator.gpu?.requestAdapter().catch(() => null);
    if (!adapter) return null;
    const library = await import("/scoutvision/assets/ort.webgpu.min.mjs");
    library.env.wasm.wasmPaths = assets;
    library.env.wasm.numThreads = 1;
    library.env.webgpu.adapter = adapter;
    return library;
  })();
  let session, input;
  try {
    const ort = await webgpuLibrary;
    if (!ort) return null;
    session = await ort.InferenceSession.create(bytes, {executionProviders:["webgpu","wasm"]});
    input = new ort.Tensor("float32",new Float32Array(3 * size * size),[1,3,size,size]);
    const outputs = await session.run({[session.inputNames[0]]:input});
    Object.values(outputs).forEach(tensor=>tensor.dispose());
    return {ort, session, name:"webgpu"};
  } catch (error) {
    console.info("ScoutVision WebGPU detector unavailable", error.message);
    await session?.release().catch(()=>{});
    return null;
  } finally { input?.dispose(); }
}

const loadingModels = new Map();
function detector(choice) {
  if (loadingModels.has(choice)) return loadingModels.get(choice);
  const loading = (async () => {
    const {prefix, size} = yoloAssets[choice];
    const bytes = await downloadModel(prefix, 2);
    const webgpu = await webgpuRuntime(bytes, size);
    if (webgpu) return webgpu;
    let runner;
    try {
      runner = await runtime("webgl", bytes);
      const input = new runner.ort.Tensor("float32", new Float32Array(3 * size * size), [1, 3, size, size]);
      try {
        const outputs = await runner.session.run({[runner.session.inputNames[0]]:input}, [runner.session.outputNames[0]]);
        Object.values(outputs).forEach(tensor => tensor.dispose());
      } finally { input.dispose(); }
    } catch (error) {
      console.info("ScoutVision WebGL detector unavailable", error.message);
      await runner?.session.release().catch(()=>{});
      runner = await runtime("wasm", bytes);
    }
    return runner;
  })().catch(error => { loadingModels.delete(choice); throw error; });
  loadingModels.set(choice, loading);
  return loading;
}

const inferenceCanvas = document.createElement("canvas");
const context = inferenceCanvas.getContext("2d", {willReadFrequently: true});

export async function detect(frame, minimum = .20, choice = "highlander", options = {}) {
  if (choice === "speedway") {
    const {detectSpeedway} = await import("./speedway.js?v=rebuild");
    return detectSpeedway(frame, minimum);
  }
  const {ort, session, name} = await detector(choice);
  const {size} = yoloAssets[choice];
  if (inferenceCanvas.width !== size) inferenceCanvas.width = inferenceCanvas.height = size;
  const ratio = Math.min(size / frame.width, size / frame.height);
  const w = frame.width * ratio, h = frame.height * ratio;
  const x = (size - w) / 2, y = (size - h) / 2;
  context.fillStyle = "#727272";
  context.fillRect(0, 0, size, size);
  context.drawImage(frame, x, y, w, h);
  const rgba = context.getImageData(0, 0, size, size).data;
  const area = size * size;
  const rgb = new Float32Array(3 * area);
  for (let i = 0; i < area; i++) {
    rgb[i] = rgba[i * 4] / 255;
    rgb[i + area] = rgba[i * 4 + 1] / 255;
    rgb[i + area * 2] = rgba[i * 4 + 2] / 255;
  }
  const input = new ort.Tensor("float32", rgb, [1, 3, size, size]);
  let result;
  try {
    const outputs = options.proposals ? session.outputNames : [session.outputNames[0]];
    result = await session.run({[session.inputNames[0]]: input}, outputs);
    const tensor = result[session.outputNames[0]], {data:values} = tensor, count = tensor.dims[2];
    const candidates = [];
    for (let i = 0; i < count; i++) {
      const score = values[4 * count + i];
      if (score < (options.proposals ? .0008 : minimum)) continue;
      const halfW = values[count * 2 + i] / 2, halfH = values[count * 3 + i] / 2;
      const centerX = values[i] - x, centerY = values[i + count] - y;
      const left = Math.max(0, (centerX - halfW) / w), top = Math.max(0, (centerY - halfH) / h);
      const right = Math.min(1, (centerX + halfW) / w), bottom = Math.min(1, (centerY + halfH) / h);
      if (right - left > .01 && bottom - top > .02) {
        candidates.push({x:left, y:top, w:right-left, h:bottom-top, score, index:i});
      }
    }
    const boxes = suppress(candidates.filter(box => box.score >= minimum));
    const proposals = options.proposals ? yoloProposals(candidates, outputs.slice(1).map(output => result[output])) : [];
    return {boxes, proposals, backend:name};
  } finally {
    input.dispose();
    if (result) Object.values(result).forEach(tensor => tensor.dispose());
  }
}

function yoloProposals(candidates, scales) {
  const features = scales.map(scale => scale.data);
  const area = scales.map(scale => scale.dims[2] * scale.dims[3]);
  const regions = new Map();
  const proposals = [];
  for (const box of candidates.sort((a,b) => b.score - a.score)) {
    const region = Math.floor((box.x + box.w/2) * 20) + "," + Math.floor((box.y + box.h/2) * 16);
    const seen = regions.get(region) || 0;
    if (seen >= 4) continue;
    regions.set(region, seen + 1);
    const level = box.index < area[0] ? 0 : box.index < area[0] + area[1] ? 1 : 2;
    const cell = box.index - (level ? area[0] : 0) - (level === 2 ? area[1] : 0);
    const embedding = new Float32Array(130);
    for (let channel = 0; channel < 128; channel++) {
      const value = features[level][channel * area[level] + cell];
      embedding[channel] = value / (1 + Math.abs(value));
    }
    embedding[128] = Math.max(-1, Math.log(box.score) / 8);
    embedding[129] = 1;
    proposals.push({box, embedding});
    if (proposals.length >= 220) break;
  }
  return proposals;
}
