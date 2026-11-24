// Teach ScoutVision to read goal stacks and toggles for a new camera.
//
// Someone labels a handful of frames: how many red, blue and yellow pins are on each goal
// and who owns each toggle. Each label becomes a reference "look" for that goal on that
// camera. During analysis the scoring reader compares every goal with these references and
// takes the closest one - or reports nothing when two different answers look too alike.
// This is the same method that reads the built-in Smoky / Mall of America / Highlander
// cameras; training here builds the reference set for a camera ScoutVision has never seen.

import {access} from "./storage.js?v=load3";
import {field} from "./tracking.js?v=load3";
import {goals, wallPoints} from "./scoring.js?v=load3";
import {closestCounts, closestOwner, FIELD_CORNERS, pixelReader, resetScoringReferences, signature} from "./scoring-model.js?v=load3";

export const WALLS = ["far", "left", "right", "near"];
export const OWNER_NAMES = ["Neutral", "Red", "Blue"];
const SAME_CAMERA = .02;

/** Where each goal and toggle sits in a frame of the given size, from the four field corners. */
export function geometry(corners, wall, width, height) {
  const {image} = field({corners, wall});
  const px = point => { const [x, y] = image(point); return [x * width, y * height]; };
  const unitAt = point => {
    const a = px(point), b = px([point[0] + 4, point[1]]), c = px([point[0], point[1] + 4]);
    return Math.max(Math.hypot(b[0] - a[0], b[1] - a[1]), Math.hypot(c[0] - a[0], c[1] - a[1])) / 4;
  };
  const round = values => values.map(Math.round);
  return {
    size: [width, height],
    corners: FIELD_CORNERS.map(image),
    goals: goals.map(goal => {
      const base = px(goal.point), unit = unitAt(goal.point);
      return {id:goal.id, name:goal.name, base:round(base),
        crop:round([base[0] - 8 * unit, base[1] - 24 * unit, base[0] + 8 * unit, base[1] + 2 * unit])};
    }),
    toggleCrops: Object.fromEntries(WALLS.map(wall => {
      const point = px(wallPoints[wall]), unit = unitAt(wallPoints[wall]);
      return [wall, round([point[0] - 11 * unit, point[1] - 13 * unit, point[0] + 11 * unit, point[1] + 4 * unit])];
    })),
  };
}

const cornerGap = (a, b) => Math.sqrt(a.reduce((sum, corner, i) =>
  sum + corner.reduce((total, value, j) => total + (value - b[i][j]) ** 2, 0), 0) / 8);

function encode(values) {
  let text = "";
  for (const value of values) text += String.fromCharCode(Math.max(0, Math.min(255, Math.round(value))));
  return btoa(text);
}

async function readLabel(label) {
  const bitmap = await createImageBitmap(label.image);
  const canvas = document.createElement("canvas");
  canvas.width = bitmap.width;
  canvas.height = bitmap.height;
  canvas.getContext("2d", {willReadFrequently:true}).drawImage(bitmap, 0, 0);
  bitmap.close();
  const geo = geometry(label.corners, label.wall, canvas.width, canvas.height);
  const read = pixelReader(canvas);
  const identity = point => point;
  return {
    label, geo,
    goals: geo.goals.flatMap(goal => {
      const counts = label.goals[goal.id];
      return Array.isArray(counts) ? [{id:goal.id, counts, values:signature(read, goal.crop, identity)}] : [];
    }),
    toggles: WALLS.flatMap(wall => Number.isInteger(label.toggles[wall]) ?
      [{wall, owner:label.toggles[wall], values:signature(read, geo.toggleCrops[wall], identity)}] : []),
  };
}

// Predict one frame from the others in its camera group, the way analysis would.
function predictGoal(entry, references, goal) {
  const examples = references.filter(item => item.id === entry.id).map(({counts, values}) => ({counts, values}));
  if (!examples.length) return null;
  const nearest = closestCounts(entry.values, examples, goal, false);
  return nearest ? nearest.counts : null;
}

function validate(group) {
  const goalsScore = {correct:0, wrong:0, unsure:0}, togglesScore = {correct:0, wrong:0, unsure:0};
  if (group.length < 2) return null;
  group.forEach((entry, i) => {
    const others = group.filter((_, j) => j !== i);
    for (const goalEntry of entry.goals) {
      const goal = entry.geo.goals.find(item => item.id === goalEntry.id);
      const predicted = predictGoal(goalEntry, others.flatMap(other => other.goals), goal);
      goalsScore[predicted === null ? "unsure" : predicted.join() === goalEntry.counts.join() ? "correct" : "wrong"]++;
    }
    for (const toggle of entry.toggles) {
      const examples = others.flatMap(other => other.toggles.filter(item => item.wall === toggle.wall));
      const predicted = examples.length ? closestOwner(toggle.values, examples) : null;
      togglesScore[predicted === null ? "unsure" : predicted === toggle.owner ? "correct" : "wrong"]++;
    }
  });
  return {goals:goalsScore, toggles:togglesScore};
}

/** Rebuild every browser-trained scoring camera from all saved scoring labels. */
export async function trainScoring(update = () => {}) {
  const labels = (await access("scoring", "getAll")).sort((a, b) => a.clip.localeCompare(b.clip) || a.at - b.at);
  if (labels.length < 3) throw new Error("Label at least three frames before training scoring.");
  const entries = [];
  for (const [i, label] of labels.entries()) {
    entries.push(await readLabel(label));
    update(i + 1, labels.length);
  }
  const groups = [];
  for (const entry of entries) {
    const group = groups.find(items => items[0].label.wall === entry.label.wall &&
      cornerGap(items[0].geo.corners, entry.geo.corners) <= SAME_CAMERA);
    group ? group.push(entry) : groups.push([entry]);
  }
  for (const old of await access("models", "getAll")) {
    if (old.kind === "scoring-camera") await access("models", "delete", old.id);
  }
  const cameras = [];
  for (const [index, group] of groups.entries()) {
    const {geo, label} = group[0];
    const references = Object.fromEntries(goals.map(goal => [goal.id, group.flatMap(entry =>
      entry.goals.filter(item => item.id === goal.id).map(item => [item.counts, encode(item.values)]))]));
    const toggleReferences = Object.fromEntries(WALLS.map(wall => [wall, group.flatMap(entry =>
      entry.toggles.filter(item => item.wall === wall).map(item => [item.owner, encode(item.values)]))]));
    const camera = {
      id:`scoring-camera:${index}:${label.clip}`, kind:"scoring-camera",
      name:`Your scoring labels · ${label.clipName || "video"}`, size:geo.size, corners:geo.corners,
      goals:geo.goals, references, toggleCrops:geo.toggleCrops, toggleReferences,
      columns:{}, unreadableGoals:[], visibleFaces:{}, toggleFaces:{}, insideFaces:{}, yellowEdges:{},
      frames:group.length, validation:validate(group), created:Date.now(),
    };
    await access("models", "put", camera);
    cameras.push(camera);
  }
  resetScoringReferences();
  return cameras.map(({name, frames, validation}) => ({name, frames, validation}));
}
