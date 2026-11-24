import {detect, overlap, suppress} from "./detector.js?v=rebuild";

const minimum = .18;
const storageKey = choice => "scoutvision-yolo-adaptation-v1-" + choice;
const sigmoid = value => 1 / (1 + Math.exp(-value));

function confidence(embedding, weights) {
  let value = 0;
  for (let i = 0; i < embedding.length; i++) value += embedding[i] * weights[i];
  return sigmoid(value);
}

export function browserDetector(choice) {
  try {
    const saved = JSON.parse(localStorage.getItem(storageKey(choice)));
    return saved?.weights.length === 130 ? saved : null;
  } catch { return null; }
}

export function adaptedBoxes(result, adjustment) {
  if (!adjustment) return result.boxes;
  const rescored = new Map();
  const boxes = result.proposals.flatMap(({box,embedding}) => {
    const confidenceScore = confidence(embedding, adjustment.weights);
    rescored.set(box.index, confidenceScore);
    if (confidenceScore < adjustment.threshold) return [];
    return [{...box, score:Math.min(.8,confidenceScore * .85)}];
  });
  const base = adjustment.rejectLow ? result.boxes.filter(box => (rescored.get(box.index) ?? 1) >= .30) : result.boxes;
  return suppress([...base, ...boxes]);
}

function evaluate(rows, adjustment) {
  const counts = {matched:0, detected:0, expected:0};
  for (const {sample,result} of rows) {
    const boxes = adaptedBoxes(result, adjustment);
    const remaining = [...sample.boxes];
    counts.detected += boxes.length;
    counts.expected += remaining.length;
    for (const box of boxes) {
      const matches = remaining.map(label => overlap(box, label));
      const best = Math.max(...matches);
      if (best < .5) continue;
      counts.matched++;
      remaining.splice(matches.indexOf(best),1);
    }
  }
  return counts;
}

export async function train(samples, choice, update) {
  const ordered = [...samples].sort((a,b) => a.clip.localeCompare(b.clip) || a.at - b.at);
  const lastClip = ordered.at(-1).clip;
  const boundary = ordered.findIndex(sample => sample.clip === lastClip);
  const heldOutClip = boundary >= 6 && ordered.length - boundary >= 2;
  const split = heldOutClip ? boundary : Math.floor(ordered.length * .8);
  const rows = [];
  for (const [index,sample] of ordered.entries()) {
    const bitmap = await createImageBitmap(sample.image);
    try {
      const result = await detect(bitmap, minimum, choice, {proposals:true});
      rows.push({sample,result});
      update(index+1, ordered.length, result.backend);
    } finally { bitmap.close(); }
  }

  const matches = [], background = [];
  for (const {sample,result} of rows.slice(0,split)) {
    for (const {box,embedding} of result.proposals) {
      const best = Math.max(0,...sample.boxes.map(label => overlap(box,label)));
      if (best >= .5) matches.push(embedding);
      else if (best < .25) background.push(embedding);
    }
  }
  if (!matches.length || !background.length) {
    throw new Error("YOLO needs more varied reviewed frames with clearly visible robots before it can learn from this set.");
  }
  const weights = new Float64Array(matches[0].length);
  for (let epoch = 0; epoch < 42; epoch++) {
    const gradient = new Float64Array(weights.length);
    for (const [examples, target] of [[matches,1], [background,0]]) {
      for (const embedding of examples) {
        const difference = (confidence(embedding,weights) - target) / examples.length;
        for (let k = 0; k < weights.length; k++) gradient[k] += difference * embedding[k];
      }
    }
    for (let k = 0; k < weights.length; k++) weights[k] -= .22 * (gradient[k] + .012 * weights[k]);
  }

  const validation = rows.slice(split);
  const baseline = evaluate(validation);
  const quality = row => 2 * row.matched / (row.detected + row.expected || 1);
  const learnedWeights = Array.from(weights);
  const trained = [false,true].flatMap(rejectLow => [.92,.84,.76,.68,.60].map(threshold => {
    const adjustment = {weights:learnedWeights,threshold,rejectLow};
    return {adjustment,counts:evaluate(validation,adjustment)};
  })).reduce((best,next) => quality(next.counts) > quality(best.counts) ? next : best);
  const saved = quality(trained.counts) > quality(baseline);
  if (saved) localStorage.setItem(storageKey(choice), JSON.stringify(trained.adjustment));
  return {...trained.counts, baseline, saved, heldOutClip, checked:validation.length};
}
