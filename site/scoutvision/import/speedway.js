import {downloadModel, loadScript, suppress, webgpuRuntime} from "./detector.js?v=load7";

const assets = "/scoutvision/assets/";
const size = 512;
const mean = [.485, .456, .406], deviation = [.229, .224, .225];
const canvas = document.createElement("canvas");
canvas.width = canvas.height = size;
const context = canvas.getContext("2d", {willReadFrequently:true});
context.imageSmoothingQuality = "high";
let loading;

async function cpu(bytes) {
  const ort = await loadScript("ort.wasm.min.js");
  ort.env.wasm.wasmPaths = assets;
  // A cross-origin isolated page can use WASM threads. Embedded browsers still work.
  ort.env.wasm.numThreads = globalThis.crossOriginIsolated ? Math.min(navigator.hardwareConcurrency || 2, 4) : 1;
  const session = await ort.InferenceSession.create(bytes, {executionProviders:["wasm"]});
  return {ort, session, backend:"wasm"};
}

function speedwayDetector() {
  loading ||= (async () => {
    const bytes = await downloadModel("speedway-rfdetr-v1", 6);
    const webgpu = await webgpuRuntime(bytes, size);
    return webgpu ? {...webgpu, backend:webgpu.name} : cpu(bytes);
  })().catch(error => { loading = undefined; throw error; });
  return loading;
}

export async function detectSpeedway(frame, minimum) {
  const {ort, session, backend} = await speedwayDetector();
  context.drawImage(frame, 0, 0, size, size);
  const rgba = context.getImageData(0, 0, size, size).data;
  const area = size * size;
  const pixels = new Float32Array(3 * area);
  for (let i = 0; i < area; i++) {
    for (let channel = 0; channel < 3; channel++) {
      pixels[channel * area + i] = (rgba[i * 4 + channel] / 255 - mean[channel]) / deviation[channel];
    }
  }
  const input = new ort.Tensor("float32", pixels, [1,3,size,size]);
  let outputs;
  try {
    outputs = await session.run({input});
    const predictions = outputs.dets.data, logits = outputs.labels.data;
    const queries = outputs.dets.dims[1], classes = outputs.labels.dims[2];
    const boxes = [];
    for (let i = 0; i < queries; i++) {
      const score = 1 / (1 + Math.exp(-logits[i * classes]));
      if (score < minimum) continue;
      const [cx, cy, width, height] = predictions.subarray(i * 4, i * 4 + 4);
      const x = Math.max(0, cx - width / 2), y = Math.max(0, cy - height / 2);
      const w = Math.min(1, cx + width / 2) - x, h = Math.min(1, cy + height / 2) - y;
      if (w > .01 && h > .02) boxes.push({x,y,w,h,score});
    }
    return {boxes:suppress(boxes), backend};
  } finally {
    input.dispose();
    if (outputs) Object.values(outputs).forEach(tensor => tensor.dispose());
  }
}
