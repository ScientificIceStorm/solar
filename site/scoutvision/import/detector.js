const assets = "/scoutvision/assets/";
const scriptLoads = new Map();

// "override" is the multi-event model (Highlander + Mall of America + Smoky). The older
// single-event models stay selectable for comparison but cannot be fine-tuned.
export const detectorNames = {
  override: "Override robots · 3 events",
  speedway: "Speedway RF-DETR Large",
  "speedway-yolo": "Speedway YOLO",
  highlander: "Highlander YOLO",
};
const yoloAssets = {
  override:{manifest:"override-multi-640-v1"},
  highlander:{prefix:"highlander-yolo-v2", size:480, parts:2},
  "speedway-yolo":{prefix:"speedway-yolo-480-v1", size:480, parts:2},
};
export const defaultDetector = "override";
export const isYolo = choice => Object.hasOwn(yoloAssets, choice);
export const canFineTune = choice => Boolean(yoloAssets[choice]?.manifest);

export function loadScript(name, global = "ort") {
  if (!scriptLoads.has(name)) {
    scriptLoads.set(name, new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = assets + name;
      script.onload = () => resolve(globalThis[global]);
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

// The page shows what the detector is doing while it loads (download progress, GPU start-up),
// so a slow first visit never looks frozen.
let reporter = () => {};
export function onLoadingStatus(callback) { reporter = callback || (() => {}); }
export const report = text => { try { reporter(text); } catch { /* the page may have moved on */ } };

// A GPU start-up that never settles (seen on some phones and Safari builds) must not hang the
// page: each backend gets a time limit, then the next one is tried.
const GPU_START_LIMIT = 30000;
function withTimeout(promise, ms, message) {
  let timer;
  return Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(message)), ms); })])
    .finally(() => clearTimeout(timer));
}

export async function downloadModel(prefix, count, label = "robot detector") {
  const received = new Array(count).fill(0), expected = new Array(count).fill(0);
  const megabytes = values => (values.reduce((a, b) => a + b, 0) / 1e6).toFixed(0);
  const parts = await Promise.all(Array.from({length: count}, async (_, index) => {
    const response = await fetch(assets + `${prefix}-${index + 1}.bin`);
    if (!response.ok) throw new Error("Could not load the selected robot detector. Check your connection and try again.");
    expected[index] = +response.headers.get("content-length") || 0;
    if (!response.body?.getReader) return new Uint8Array(await response.arrayBuffer());
    const reader = response.body.getReader(), chunks = [];
    for (;;) {
      const {done, value} = await reader.read();
      if (done) break;
      chunks.push(value);
      received[index] += value.length;
      const total = expected.every(Boolean) ? ` of ${megabytes(expected)} MB` : " MB";
      report(`Downloading the ${label}: ${megabytes(received)}${total} (first time only)…`);
    }
    const part = new Uint8Array(received[index]);
    let offset = 0;
    for (const chunk of chunks) { part.set(chunk, offset); offset += chunk.length; }
    return part;
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
    ort.env.wasm.numThreads = globalThis.crossOriginIsolated ? Math.min(navigator.hardwareConcurrency || 2, 4) : 1;
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
    report("Starting the detector on your GPU (WebGPU, up to 30 s the first time)…");
    return await withTimeout((async () => {
      const ort = await webgpuLibrary;
      if (!ort) return null;
      session = await ort.InferenceSession.create(bytes, {executionProviders:["webgpu","wasm"]});
      input = new ort.Tensor("float32",new Float32Array(3 * size * size),[1,3,size,size]);
      const outputs = await session.run({[session.inputNames[0]]:input});
      Object.values(outputs).forEach(tensor=>tensor.dispose());
      return {ort, session, name:"webgpu"};
    })(), GPU_START_LIMIT, "WebGPU did not start in time.");
  } catch (error) {
    console.info("ScoutVision WebGPU detector unavailable", error.message);
    await session?.release().catch(()=>{});
    return null;
  } finally { input?.dispose(); }
}

const manifests = new Map();
export function modelManifest(choice) {
  const asset = yoloAssets[choice];
  if (!asset?.manifest) return Promise.resolve({name:asset.prefix, size:asset.size, parts:asset.parts, features:[]});
  if (!manifests.has(choice)) {
    manifests.set(choice, fetch(assets + asset.manifest + ".json").then(response => {
      if (!response.ok) throw new Error("Could not load the robot detector description.");
      return response.json();
    }).catch(error => { manifests.delete(choice); throw error; }));
  }
  return manifests.get(choice);
}

const loadingModels = new Map();
function detector(choice) {
  if (loadingModels.has(choice)) return loadingModels.get(choice);
  const loading = (async () => {
    const manifest = await modelManifest(choice);
    const {name, size, parts} = manifest;
    const bytes = await downloadModel(name, parts);
    const webgpu = await webgpuRuntime(bytes, size);
    if (webgpu) return {...webgpu, manifest};
    let runner;
    try {
      report("WebGPU is unavailable here. Starting the detector with WebGL…");
      runner = await withTimeout((async () => {
        const started = await runtime("webgl", bytes);
        runner = started;
        const input = new started.ort.Tensor("float32", new Float32Array(3 * size * size), [1, 3, size, size]);
        try {
          const outputs = await started.session.run({[started.session.inputNames[0]]:input});
          Object.values(outputs).forEach(tensor => tensor.dispose());
        } finally { input.dispose(); }
        return started;
      })(), GPU_START_LIMIT, "WebGL did not start in time.");
    } catch (error) {
      console.info("ScoutVision WebGL detector unavailable", error.message);
      await runner?.session.release().catch(()=>{});
      report("No usable GPU found. Starting the detector on the CPU; analysis will be slower…");
      runner = await runtime("wasm", bytes);
    }
    report("Detector ready. Reading the first frame…");
    return {...runner, manifest};
  })().catch(error => { loadingModels.delete(choice); throw error; });
  loadingModels.set(choice, loading);
  return loading;
}

const inferenceCanvas = document.createElement("canvas");
const context = inferenceCanvas.getContext("2d", {willReadFrequently: true});

/**
 * Detect robots in a canvas/bitmap. Boxes are normalised to the frame.
 * options.raw  - also return the letterbox geometry, every anchor's score and box, and
 *                the neck feature maps (needed to train or apply a fine-tuned head).
 * options.head - a fine-tuned head from finetune.js; its scores replace the base scores.
 */
export async function detect(frame, minimum = .20, choice = defaultDetector, options = {}) {
  if (choice === "speedway") {
    const {detectSpeedway} = await import("./speedway.js?v=load9");
    return detectSpeedway(frame, minimum);
  }
  const {ort, session, name, manifest} = await detector(choice);
  const {size} = manifest;
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
  const wantFeatures = Boolean((options.raw || options.head) && manifest.features.length);
  const fetches = [session.outputNames[0], ...(wantFeatures ? manifest.features.map(feature => feature.name) : [])];
  let result;
  try {
    result = await session.run({[session.inputNames[0]]: input}, fetches);
    const tensor = result[session.outputNames[0]];
    const count = tensor.dims[2];
    const values = tensor.data;
    const letterbox = {size, x, y, w, h};
    const raw = wantFeatures ? {
      letterbox, count,
      scores: values.slice(4 * count, 5 * count),
      boxes: values.slice(0, 4 * count),
      features: manifest.features.map(feature => ({...feature, data: result[feature.name].data.slice()})),
    } : null;
    let scores = values.subarray(4 * count, 5 * count), boxValues = values, cut = minimum;
    if (options.head && raw) {
      const adapted = await options.head.apply(raw);
      scores = adapted.scores;
      boxValues = adapted.boxes;
      // The head picked its own threshold on held-out frames; keep callers' relative leniency.
      cut = options.head.threshold * minimum / .18;
    }
    const candidates = [];
    for (let i = 0; i < count; i++) {
      const score = scores[i];
      if (score < cut) continue;
      const halfW = boxValues[count * 2 + i] / 2, halfH = boxValues[count * 3 + i] / 2;
      const centerX = boxValues[i] - x, centerY = boxValues[i + count] - y;
      const left = Math.max(0, (centerX - halfW) / w), top = Math.max(0, (centerY - halfH) / h);
      const right = Math.min(1, (centerX + halfW) / w), bottom = Math.min(1, (centerY + halfH) / h);
      if (right - left > .01 && bottom - top > .02) {
        candidates.push({x:left, y:top, w:right-left, h:bottom-top, score, index:i});
      }
    }
    return {boxes:suppress(candidates), backend:name, raw:options.raw ? raw : undefined};
  } finally {
    input.dispose();
    if (result) Object.values(result).forEach(tensor => tensor.dispose());
  }
}
