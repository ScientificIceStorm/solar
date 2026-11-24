// In-browser fine-tuning of the robot detector.
//
// The YOLO backbone and neck run in ONNX Runtime and stay frozen. Their three feature maps
// (strides 8, 16, 32) feed the YOLO detection head, whose weights are exported next to the
// model (<name>-head.bin, batch norm folded in). Here that head is rebuilt in TF.js and
// fine-tuned on the user's reviewed frames with YOLO's own training loss: task-aligned
// assignment, IoU box loss, distribution focal loss and BCE classification.
//
// An untrained head reproduces the base model exactly, so training starts from what the
// base model already knows. Every fourth frame (or the last video) is held out; the head is
// only saved if it beats the base model on those frames.

import {detect, loadScript, modelManifest, overlap, suppress} from "./detector.js?v=train2";
import {access} from "./storage.js?v=train2";

// Tunable from the console for experiments; defaults chosen on held-out Mall of America frames.
export const settings = {steps:150, batch:4, rate:2e-4, checkEvery:10, topk:10};
const THRESHOLDS = [.10, .14, .18, .22, .26, .30, .35, .40, .50, .60];
const BINS = 16;
const headId = modelName => "detector-head:" + modelName;
const pause = () => new Promise(resolve => setTimeout(resolve, 0)); // rAF would stall in a hidden tab
let tfLoading;

async function tensorflow() {
  tfLoading ||= (async () => {
    const tf = await loadScript("tf.min.js", "tf");
    for (const backend of ["webgl", "cpu"]) {
      try { if (await tf.setBackend(backend)) break; } catch { /* try the next backend */ }
    }
    await tf.ready();
    return tf;
  })().catch(error => { tfLoading = undefined; throw error; });
  return tfLoading;
}

const headFiles = new Map();
async function baseHead(manifest) {
  if (!manifest.head) throw new Error("This detector has no trainable head. Choose the 3-event Override model.");
  if (!headFiles.has(manifest.name)) {
    headFiles.set(manifest.name, fetch("/scoutvision/assets/" + manifest.head.file).then(async response => {
      if (!response.ok) throw new Error("Could not load the detector head weights.");
      return new Float32Array(await response.arrayBuffer());
    }).catch(error => { headFiles.delete(manifest.name); throw error; }));
  }
  return headFiles.get(manifest.name);
}

const size = shape => shape.reduce((a, b) => a * b, 1);
function unpack(manifest, blob) {
  return Object.fromEntries(manifest.head.tensors.map(({name, shape, offset}) =>
    [name, {shape, values: blob.subarray(offset, offset + size(shape))}]));
}

// Anchor centres in grid units, and each anchor's stride, in YOLO's output order.
function anchors(features) {
  const count = features.reduce((total, f) => total + f.width * f.height, 0);
  const grid = new Float32Array(count * 2), strides = new Float32Array(count), pixels = new Float32Array(count * 2);
  let i = 0;
  for (const {width, height, stride} of features) {
    for (let row = 0; row < height; row++) for (let col = 0; col < width; col++, i++) {
      grid[i * 2] = col + .5; grid[i * 2 + 1] = row + .5; strides[i] = stride;
      pixels[i * 2] = (col + .5) * stride; pixels[i * 2 + 1] = (row + .5) * stride;
    }
  }
  return {count, grid, strides, pixels};
}

const silu = (tf, x) => x.mul(tf.sigmoid(x));
function forward(tf, W, inputs) {
  const dists = [], logits = [];
  inputs.forEach((x, l) => {
    const conv = (input, name, act = true) => {
      const y = tf.conv2d(input, W[name + ".w"], 1, "same").add(W[name + ".b"]);
      return act ? silu(tf, y) : y;
    };
    const depthwise = (input, name) => silu(tf, tf.depthwiseConv2d(input, W[name + ".w"], 1, "same").add(W[name + ".b"]));
    const box = conv(conv(conv(x, `box${l}.0`), `box${l}.1`), `box${l}.2`, false);
    const cls = conv(conv(depthwise(conv(depthwise(x, `cls${l}.0`), `cls${l}.1`), `cls${l}.2`), `cls${l}.3`), `cls${l}.4`, false);
    const [batch, height, width] = x.shape;
    dists.push(box.reshape([batch, height * width, 4, BINS]));
    logits.push(cls.reshape([batch, height * width]));
  });
  return {dist: tf.concat(dists, 1), logits: tf.concat(logits, 1)};
}

// Expected distance (grid units) from the 16-bin distributions.
const expectation = (tf, dist) => tf.softmax(dist).mul(tf.range(0, BINS).reshape([1, BINS])).sum(-1);

function featureInputs(tf, raws) {
  return raws[0].features.map((_, l) => tf.concat(raws.map(raw => {
    const {data, channels, height, width} = raw.features[l];
    return tf.tensor4d(data, [1, channels, height, width]).transpose([0, 2, 3, 1]);
  }), 0));
}

// Run a head on frames; returns per-frame scores and boxes in YOLO's output0 layout.
async function predict(tf, W, raws, grid) {
  const [distances, probabilities] = tf.tidy(() => {
    const {dist, logits} = forward(tf, W, featureInputs(tf, raws));
    return [expectation(tf, dist), tf.sigmoid(logits)];
  });
  const [ltrb, scoreValues] = await Promise.all([distances.data(), probabilities.data()]);
  distances.dispose(); probabilities.dispose();
  const {count, strides} = grid;
  return raws.map((_, b) => {
    const scores = scoreValues.slice(b * count, (b + 1) * count), boxes = new Float32Array(4 * count);
    for (let a = 0; a < count; a++) {
      const o = (b * count + a) * 4, s = strides[a], gx = grid.grid[a * 2], gy = grid.grid[a * 2 + 1];
      const x1 = (gx - ltrb[o]) * s, y1 = (gy - ltrb[o + 1]) * s, x2 = (gx + ltrb[o + 2]) * s, y2 = (gy + ltrb[o + 3]) * s;
      boxes[a] = (x1 + x2) / 2; boxes[count + a] = (y1 + y2) / 2; boxes[2 * count + a] = x2 - x1; boxes[3 * count + a] = y2 - y1;
    }
    return {scores, boxes};
  });
}

function iouXyxy(a, b) {
  const w = Math.max(0, Math.min(a[2], b[2]) - Math.max(a[0], b[0])), h = Math.max(0, Math.min(a[3], b[3]) - Math.max(a[1], b[1]));
  const inter = w * h;
  return inter / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter || 1);
}

// YOLOv8/11 task-aligned assignment: for each labelled robot, the top-k anchors inside it
// ranked by score^0.5 * IoU^6. Target scores are the alignment, normalised per robot.
function assign(prediction, truth, grid) {
  const {count, pixels} = grid, {scores, boxes} = prediction;
  const best = new Map();
  truth.forEach((gt, g) => {
    const candidates = [];
    for (let a = 0; a < count; a++) {
      const ax = pixels[a * 2], ay = pixels[a * 2 + 1];
      if (ax <= gt[0] || ax >= gt[2] || ay <= gt[1] || ay >= gt[3]) continue;
      const cx = boxes[a], cy = boxes[count + a], w = boxes[2 * count + a], h = boxes[3 * count + a];
      const iou = iouXyxy([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], gt);
      candidates.push({a, iou, align: Math.sqrt(scores[a]) * iou ** 6});
    }
    candidates.sort((x, y) => y.align - x.align);
    const chosen = candidates.slice(0, settings.topk);
    const maxAlign = Math.max(1e-9, ...chosen.map(c => c.align)), maxIou = Math.max(0, ...chosen.map(c => c.iou));
    for (const c of chosen) {
      const previous = best.get(c.a);
      if (!previous || c.iou > previous.iou) best.set(c.a, {g, iou:c.iou, score: c.align / maxAlign * maxIou});
    }
  });
  return [...best].map(([a, {g, score}]) => ({a, g, score}));
}

const toLetterbox = (raw, box) => {
  const {x, y, w, h} = raw.letterbox;
  return [x + box.x * w, y + box.y * h, x + (box.x + box.w) * w, y + (box.y + box.h) * h];
};

function loss(tf, W, batch, grid, targets) {
  const {count} = grid;
  const {dist, logits} = forward(tf, W, featureInputs(tf, batch.map(item => item.raw)));
  const targetScores = new Float32Array(batch.length * count);
  const positives = [], weights = [], boxesTarget = [], anchorPx = [], strides = [];
  targets.forEach((list, b) => list.forEach(({a, g, score}) => {
    targetScores[b * count + a] = score;
    if (score <= 0) return;
    positives.push(b * count + a);
    weights.push(score);
    boxesTarget.push(...batch[b].truth[g]);
    anchorPx.push(grid.pixels[a * 2], grid.pixels[a * 2 + 1]);
    strides.push(grid.strides[a]);
  }));
  const total = Math.max(1, weights.reduce((s, v) => s + v, 0));
  const y = tf.tensor2d(targetScores, [batch.length, count]);
  const classification = tf.add(tf.relu(logits).sub(logits.mul(y)), tf.log1p(tf.exp(logits.abs().neg()))).sum().div(total);
  if (!positives.length) return classification.mul(.5);
  const index = tf.tensor1d(positives, "int32");
  const picked = tf.gather(dist.reshape([batch.length * count, 4, BINS]), index);
  const ltrb = expectation(tf, picked);
  const anchor = tf.tensor2d(anchorPx, [positives.length, 2]), stride = tf.tensor2d(strides, [positives.length, 1]);
  const scaled = ltrb.mul(stride);
  const pred = tf.concat([anchor.sub(scaled.slice([0, 0], [-1, 2])), anchor.add(scaled.slice([0, 2], [-1, 2]))], 1);
  const truth = tf.tensor2d(boxesTarget, [positives.length, 4]);
  const w = tf.tensor1d(weights);
  // GIoU box loss
  const [p1, p2] = [pred.slice([0, 0], [-1, 2]), pred.slice([0, 2], [-1, 2])];
  const [t1, t2] = [truth.slice([0, 0], [-1, 2]), truth.slice([0, 2], [-1, 2])];
  const area = (a, b) => tf.relu(b.sub(a)).prod(1);
  const inter = area(tf.maximum(p1, t1), tf.minimum(p2, t2));
  const union = area(p1, p2).add(area(t1, t2)).sub(inter).add(1e-7);
  const hull = area(tf.minimum(p1, t1), tf.maximum(p2, t2)).add(1e-7);
  const giou = inter.div(union).sub(hull.sub(union).div(hull));
  const boxLoss = tf.sub(1, giou).mul(w).sum().div(total);
  // Distribution focal loss on the target distances (grid units)
  const anchorGrid = anchor.div(stride);
  const target = tf.concat([anchorGrid.sub(t1.div(stride)), t2.div(stride).sub(anchorGrid)], 1).clipByValue(0, BINS - 1.01);
  const left = target.floor(), rightWeight = target.sub(left), leftWeight = tf.sub(1, rightWeight);
  const logp = tf.logSoftmax(picked);
  const leftIndex = left.toInt(), rightIndex = left.add(1).toInt();
  const pick = indices => logp.mul(tf.oneHot(indices, BINS)).sum(-1);
  const dfl = pick(leftIndex).mul(leftWeight).add(pick(rightIndex).mul(rightWeight)).neg().mean(1);
  const dflLoss = dfl.mul(w).sum().div(total);
  return boxLoss.mul(7.5).add(classification.mul(.5)).add(dflLoss.mul(1.5));
}

function decode(raw, scores, boxes, minimum) {
  const {count, letterbox:{x, y, w, h}} = raw;
  const candidates = [];
  for (let i = 0; i < count; i++) {
    if (scores[i] < minimum) continue;
    const cx = boxes[i] - x, cy = boxes[count + i] - y, bw = boxes[2 * count + i], bh = boxes[3 * count + i];
    const left = Math.max(0, (cx - bw / 2) / w), top = Math.max(0, (cy - bh / 2) / h);
    const right = Math.min(1, (cx + bw / 2) / w), bottom = Math.min(1, (cy + bh / 2) / h);
    if (right - left > .01 && bottom - top > .02) candidates.push({x:left, y:top, w:right - left, h:bottom - top, score:scores[i]});
  }
  return suppress(candidates);
}

export function countMatches(boxes, labels) {
  const remaining = [...labels];
  let matched = 0;
  for (const box of boxes) {
    const overlaps = remaining.map(label => overlap(box, label));
    const best = Math.max(-1, ...overlaps);
    if (best < .5) continue;
    matched++;
    remaining.splice(overlaps.indexOf(best), 1);
  }
  return {matched, detected:boxes.length, expected:labels.length};
}

const f1 = ({matched, detected, expected}) => 2 * matched / (detected + expected || 1);

function score(frames, predictions) {
  const totals = THRESHOLDS.map(() => ({matched:0, detected:0, expected:0}));
  frames.forEach((frame, i) => {
    const {scores, boxes} = predictions[i];
    THRESHOLDS.forEach((threshold, k) => {
      const counts = countMatches(decode(frame.raw, scores, boxes, threshold), frame.labels);
      for (const key in counts) totals[k][key] += counts[key];
    });
  });
  const best = totals.reduce((choice, counts, k) => f1(counts) > f1(totals[choice]) ? k : choice, 0);
  return {...totals[best], threshold:THRESHOLDS[best], f1:f1(totals[best])};
}

async function measure(tf, W, frames, grid) {
  const predictions = [];
  for (let i = 0; i < frames.length; i += settings.batch) {
    predictions.push(...await predict(tf, W, frames.slice(i, i + settings.batch).map(f => f.raw), grid));
  }
  return score(frames, predictions);
}

function split(samples) {
  const ordered = [...samples].sort((a, b) => a.clip.localeCompare(b.clip) || a.at - b.at);
  const clips = [...new Set(ordered.map(sample => sample.clip))];
  const last = ordered.filter(sample => sample.clip === clips.at(-1));
  if (clips.length > 1 && last.length >= 2 && ordered.length - last.length >= 6) {
    return {train:ordered.filter(sample => sample.clip !== clips.at(-1)), validation:last, heldOutClip:true};
  }
  // One clip: every fourth frame (spread across the match) is held out.
  return {train:ordered.filter((_, i) => i % 4 !== 3), validation:ordered.filter((_, i) => i % 4 === 3), heldOutClip:false};
}

function random(seed) {
  let state = seed >>> 0 || 1;
  return () => ((state = Math.imul(state ^ state >>> 15, 2246822507) + 1013904223 >>> 0) / 4294967296);
}

async function fit(tf, manifest, blob, frames, grid, steps, onCheck) {
  const parts = unpack(manifest, blob);
  const W = Object.fromEntries(Object.entries(parts).map(([name, {shape, values}]) => [name, tf.variable(tf.tensor(values, shape))]));
  const optimizer = tf.train.adam(settings.rate);
  const next = random(11);
  let order = [];
  try {
    for (let step = 1; step <= steps; step++) {
      if (order.length < settings.batch) order = [...order, ...frames.map((_, i) => i).sort(() => next() - .5)];
      const batch = order.splice(0, Math.min(settings.batch, frames.length)).map(i => frames[i]);
      const predictions = await predict(tf, W, batch.map(item => item.raw), grid);
      const targets = batch.map((item, b) => assign(predictions[b], item.truth, grid));
      optimizer.minimize(() => loss(tf, W, batch, grid, targets), false, Object.values(W));
      if (onCheck && step % settings.checkEvery === 0) await onCheck(step, W);
      await pause();
    }
    return Object.fromEntries(Object.entries(W).map(([name, variable]) => [name, variable.dataSync().slice()]));
  } finally {
    optimizer.dispose();
    Object.values(W).forEach(variable => variable.dispose());
  }
}

function pack(manifest, weights) {
  const blob = new Float32Array(manifest.head.tensors.reduce((total, t) => total + size(t.shape), 0));
  for (const t of manifest.head.tensors) blob.set(weights[t.name], t.offset);
  return blob;
}

/**
 * Fine-tune the detection head on reviewed frames: [{clip, at, image:Blob, boxes:[{x,y,w,h}]}].
 * Returns base and trained scores on held-out frames, and whether the head was saved.
 */
export async function trainDetector(samples, choice, update) {
  const tf = await tensorflow();
  const manifest = await modelManifest(choice);
  const blob = await baseHead(manifest);
  const grid = anchors(manifest.features);
  const {train, validation, heldOutClip} = split(samples);
  const frames = [];
  for (const [index, sample] of [...train, ...validation].entries()) {
    const bitmap = await createImageBitmap(sample.image);
    try {
      const result = await detect(bitmap, .18, choice, {raw:true});
      frames.push({raw:result.raw, labels:sample.boxes, truth:sample.boxes.map(box => toLetterbox(result.raw, box)),
        held:index >= train.length});
      update("Reading frames", index + 1, train.length + validation.length, result.backend);
    } finally { bitmap.close(); }
  }
  const trainFrames = frames.filter(frame => !frame.held), held = frames.filter(frame => frame.held);
  if (!trainFrames.some(frame => frame.labels.length)) throw new Error("Save more reviewed frames with visible robots before training.");
  const baseWeights = unpack(manifest, blob);
  const baseVariables = Object.fromEntries(Object.entries(baseWeights).map(([name, {shape, values}]) => [name, tf.tensor(values, shape)]));
  const base = await measure(tf, baseVariables, held, grid);
  Object.values(baseVariables).forEach(tensor => tensor.dispose());
  let best = {...base, step:0};
  await fit(tf, manifest, blob, trainFrames, grid, settings.steps, async (step, W) => {
    const result = await measure(tf, W, held, grid);
    if (result.f1 > best.f1 + .005) best = {...result, step};
    update("Training", step, settings.steps, tf.getBackend());
  });
  let saved = null;
  if (best.step > 0) {
    update("Final pass on all frames", 0, best.step, tf.getBackend());
    const weights = await fit(tf, manifest, blob, frames, grid, best.step, async step => update("Final pass on all frames", step, best.step, tf.getBackend()));
    saved = {id:headId(manifest.name), kind:"detector-head", model:manifest.name, modelBytes:manifest.bytes, choice, format:"yolo-head-v1",
      threshold:best.threshold, weights:pack(manifest, weights), frames:frames.length, created:Date.now(),
      validation:{base, trained:{matched:best.matched, detected:best.detected, expected:best.expected,
        f1:best.f1, threshold:best.threshold}, frames:held.length, heldOutClip}};
    await access("models", "put", saved);
    heads.delete(choice);
  }
  return {base, trained:best, saved:Boolean(saved), checked:held.length, heldOutClip, frames:frames.length};
}

const heads = new Map();
/** Load this browser's trained head for a detector, or null. */
export async function loadHead(choice) {
  if (!heads.has(choice)) {
    heads.set(choice, (async () => {
      const manifest = await modelManifest(choice).catch(() => null);
      if (!manifest?.head) return null;
      const saved = await access("models", "get", headId(manifest.name)).catch(() => null);
      // A head only fits the exact base model it was trained on.
      if (saved?.format !== "yolo-head-v1" || saved.modelBytes !== manifest.bytes) return null;
      const tf = await tensorflow();
      const grid = anchors(manifest.features);
      const W = Object.fromEntries(Object.entries(unpack(manifest, saved.weights)).map(([name, {shape, values}]) =>
        [name, tf.tensor(values, shape)]));
      return {...saved, apply: async raw => (await predict(tf, W, [raw], grid))[0]};
    })().catch(error => { heads.delete(choice); throw error; }));
  }
  return heads.get(choice);
}

export async function forgetHead(choice) {
  const manifest = await modelManifest(choice);
  await access("models", "delete", headId(manifest.name));
  heads.delete(choice);
}

// Internals, exposed for console experiments (see tools/eval_browser_detector.py for the offline side).
export const debug = {tensorflow, baseHead, unpack, anchors, predict, assign, measure, fit, split, toLetterbox, score};
