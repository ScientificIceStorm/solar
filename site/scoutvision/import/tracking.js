import {detect, isYolo, report, suppress} from "./detector.js?v=load5";
import {loadHead} from "./finetune.js?v=load5";
import {buildScoring} from "./scoring.js?v=load5";
import {scoringReferences} from "./scoring-model.js?v=load5";

const square = [[0,0], [144,0], [144,144], [0,144]];
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const distance = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

export function homography(source, target) {
  const matrix = source.flatMap(([x, y], i) => {
    const [u, v] = target[i];
    return [[x,y,1,0,0,0,-x*u,-y*u,u], [0,0,0,x,y,1,-x*v,-y*v,v]];
  });
  for (let i = 0; i < 8; i++) {
    let pivot = i;
    for (let row = i + 1; row < 8; row++) {
      if (Math.abs(matrix[row][i]) > Math.abs(matrix[pivot][i])) pivot = row;
    }
    if (Math.abs(matrix[pivot][i]) < 1e-9) throw new Error("Mark four separate corners of the playing surface.");
    [matrix[i], matrix[pivot]] = [matrix[pivot], matrix[i]];
    const divisor = matrix[i][i];
    matrix[i] = matrix[i].map(value => value / divisor);
    for (let row = 0; row < 8; row++) {
      if (row === i) continue;
      const factor = matrix[row][i];
      matrix[row] = matrix[row].map((value, col) => value - factor * matrix[i][col]);
    }
  }
  const [a,b,c,d,e,f,g,h] = matrix.map(row => row[8]);
  return ([x,y]) => [(a*x + b*y+c)/(g*x+h*y+1), (d*x+e*y+f)/(g*x+h*y+1)];
}

export function field(meta) {
  const offset = ["left", "far", "right", "near"].indexOf(meta.wall);
  const corners = [...meta.corners.slice(offset), ...meta.corners.slice(0, offset)];
  const winding = corners.map(([x,y], i) => {
    const [u,v] = corners[(i + 1) % 4], [r,s] = corners[(i + 2) % 4];
    return (u-x)*(s-v) - (v-y)*(r-u);
  });
  if (winding.some(value => value < .006)) {
    throw new Error("Mark the four inside corners clockwise, starting top left. Include the full field.");
  }
  return {project:homography(corners, square), image:homography(square, corners)};
}

export async function seekFrame(video, seconds, canvas, signal) {
  if (signal?.aborted) throw signal.reason;
  const at = clamp(seconds, 0, Math.max(0, video.duration - .025));
  if (Math.abs(video.currentTime - at) > .005 || video.readyState < 2) {
    await new Promise((resolve, reject) => {
      const abort = () => end(signal.reason);
      const complete = () => end();
      const fail = () => end(new Error("The browser could not decode that video frame."));
      function end(error) {
        video.removeEventListener("seeked", complete);
        video.removeEventListener("error", fail);
        signal?.removeEventListener("abort", abort);
        clearTimeout(timer);
        error ? reject(error) : resolve();
      }
      const timer = setTimeout(fail, 12000);
      video.addEventListener("seeked", complete);
      video.addEventListener("error", fail);
      signal?.addEventListener("abort", abort, {once:true});
      video.currentTime = at;
      if (video.readyState < 2 && !video.seeking) video.addEventListener("loadeddata", complete, {once:true});
    });
  }
  const ratio = Math.min(1, 960 / video.videoWidth);
  const width = Math.round(video.videoWidth * ratio), height = Math.round(video.videoHeight * ratio);
  if (canvas.width !== width || canvas.height !== height) {
    canvas.width = width;
    canvas.height = height;
  }
  canvas.getContext("2d", {willReadFrequently:true}).drawImage(video, 0, 0, width, height);
}

function cropField(frame, corners, crop) {
  const xs = corners.map(point => point[0]), ys = corners.map(point => point[1]);
  const x = Math.max(0, Math.min(...xs) - .045), y = Math.max(0, Math.min(...ys) - .12);
  const w = Math.min(1, Math.max(...xs) + .045) - x;
  const h = Math.min(1, Math.max(...ys) + .04) - y;
  const width = Math.round(frame.width * w), height = Math.round(frame.height * h);
  if (crop.width !== width || crop.height !== height) {
    crop.width = width;
    crop.height = height;
  }
  crop.getContext("2d").drawImage(frame, x*frame.width, y*frame.height, width, height, 0, 0, width, height);
  return box => ({...box, x:x + box.x*w, y:y + box.y*h, w:box.w*w, h:box.h*h});
}

function appearance(frame, box) {
  const values = new Float32Array(12);
  const left = Math.floor(box.x * frame.width), top = Math.floor(box.y * frame.height);
  const width = Math.max(1, Math.round(box.w * frame.width)), height = Math.max(1, Math.round(box.h * frame.height));
  const {data} = frame.getContext("2d").getImageData(left, top, width, height);
  let count = 0;
  for (let i = 0; i < data.length; i += 28) {
    const r = data[i], g = data[i+1], b = data[i+2];
    const hi = Math.max(r, g, b), low = Math.min(r, g, b);
    const band = Math.min(2, Math.floor(hi / 86));
    const color = hi - low < 32 ? 0 : hi === r ? 1 : hi === g ? 2 : 3;
    values[band * 4 + color]++;
    count++;
  }
  return values.map(value => value / (count || 1));
}

function assign(slots, points, dt) {
  const costs = slots.map(slot => points.map(point => {
    const next = slot.xy.map((value, k) => value + slot.velocity[k] * dt);
    const gap = distance(next, point.xy);
    if (gap > 29 + Math.min(51, slot.missed * 9)) return Infinity;
    const look = template => template ? point.appearance.reduce((sum, value, k) =>
      sum + Math.abs(value - template[k]), 0) : 0;
    const age = Math.min(slot.missed, 5);
    return gap / (1 + age * .19) + (1 - point.score) * 10 +
      look(slot.appearance) * 10 + look(slot.reference) * (9 + age * 2);
  }));
  let bestCost = Infinity, best;
  function search(i, used, choices, cost) {
    if (cost >= bestCost) return;
    if (i === slots.length) { best = [...choices]; bestCost = cost; return; }
    for (let k = 0; k < points.length; k++) {
      if (used & (1 << k)) continue;
      choices.push(k);
      search(i + 1, used | (1 << k), choices, cost + costs[i][k]);
      choices.pop();
    }
    choices.push(-1);
    search(i + 1, used, choices, cost + 37 + Math.min(12, slots[i].missed * 3));
    choices.pop();
  }
  search(0, 0, [], 0);
  return slots.map((slot, i) => {
    const index = best[i];
    const point = points[index];
    const ambiguous = point && costs.some((others, j) => j !== i &&
      best[j] < 0 && others[index] < costs[i][index] + 3);
    if (!point || ambiguous) {
      slot.missed++;
      slot.velocity = slot.velocity.map(value => value * .38);
      if (slot.missed < 3) slot.xy = slot.xy.map((value, k) => clamp(value + slot.velocity[k] * dt, 0, 144));
      return [...slot.xy, slot.missed < 3 ? 2 : 0];
    }
    slot.velocity = slot.xy.map((value, k) =>
      clamp((point.xy[k] - value) / dt, -85, 85) * .65 + slot.velocity[k] * .35);
    slot.xy = point.xy.map(value => clamp(value, 0, 144));
    if (!slot.reference && point.score >= .55) slot.reference = point.appearance;
    slot.appearance = slot.appearance ? slot.appearance.map((value, k) =>
      value * .93 + point.appearance[k] * .07) : point.appearance;
    slot.missed = 0;
    return [...slot.xy, 1];
  });
}

function bridgeBriefGaps(rows, fps) {
  let previous = -1;
  rows.forEach((current, frame) => {
    if (current[2] !== 1) return;
    if (previous >= 0 && frame - previous <= fps * 1.5 && distance(rows[previous], current) <= 37) {
      for (let next = previous + 1; next < frame; next++) {
        if (rows[next][2] === 1) continue;
        const fraction = (next - previous) / (frame - previous);
        rows[next] = [rows[previous][0] + fraction * (current[0] - rows[previous][0]),
          rows[previous][1] + fraction * (current[1] - rows[previous][1]), 2];
      }
    }
    previous = frame;
  });
}

const MISCLICK_INCHES = 36;
const outsideBy = ([x, y]) => Math.max(0, -x, x - 144, -y, y - 144);

/**
 * Where each robot mark lands on the field. Marks up to 3 ft outside the outline are moved
 * to its edge; `problem` describes anything worse. Used while marking and before analysis.
 */
export function robotPlacement(meta) {
  let project;
  try { ({project} = field(meta)); }
  catch (error) { return {problem:error.message, seeds:[], notes:[]}; }
  const points = meta.robots.map(project);
  const robots = points.map((point, i) => ({team:meta.teams[i]?.team || `Robot ${i + 1}`, off:outsideBy(point)}));
  const far = robots.filter(robot => robot.off > MISCLICK_INCHES);
  const problem = far.length ? `${far.map(robot => `${robot.team} is marked ${Math.round(robot.off)} in outside the field`).join("; ")}. ` +
    "Mark the four inside floor corners clockwise from the top-left of the picture, then click each robot where its wheels touch the floor." : null;
  const notes = robots.filter(robot => robot.off > 2 && robot.off <= MISCLICK_INCHES)
    .map(robot => `${robot.team} is ${Math.round(robot.off)} in outside the outline and will start at its edge`);
  return {problem, notes, seeds:points.map(([x, y]) => [clamp(x, 0, 144), clamp(y, 0, 144)])};
}

export async function analyze(video, meta, update, signal) {
  report("Loading the scoring references…");
  const scoringModel = await scoringReferences();
  report("Reading the first video frame…");
  const {project, image} = field(meta);
  // A robot marked a little outside the outline (common when the camera cuts off a field edge)
  // starts at the nearest edge instead; the tracker picks it up from the detections. Only a
  // clear mis-click is refused.
  const placement = robotPlacement(meta);
  if (placement.problem) throw new Error(placement.problem);
  const seeds = placement.seeds;
  const duration = meta.end - meta.start, fps = 20;
  const last = Math.round(duration * fps);
  const tracks = Object.fromEntries(meta.teams.map(entry => [entry.team, []]));
  const slots = seeds.map(xy => ({xy, velocity:[0,0], missed:0}));
  const frame = document.createElement("canvas"), crop = document.createElement("canvas");
  const pointsSeen = slots.map(() => 0);
  const yolo = isYolo(meta.detector);
  const head = meta.adapted && yolo ? await loadHead(meta.detector) : null;
  const insideField = box => project([box.x + box.w / 2, box.y + box.h * .94])
    .every(value => value >= -12 && value <= 156);
  let scoring, provider, observed = 0, previousFrame = 0, step = fps / 2;
  for (let indexFrame = 0; ; indexFrame = Math.min(last, indexFrame + step)) {
    if (signal.aborted) throw signal.reason;
    await seekFrame(video, meta.start + indexFrame / fps, frame, signal);
    if (!observed) {
      report("Setting up goal and toggle reading…");
      scoring = buildScoring(frame, image, meta.teams, fps, scoringModel);
      report("Loading the robot detector…");
    }
    const cameraClear = !observed || scoring.cameraMatches(frame);
    let boxes = [];
    if (cameraClear) {
      const inference = await detect(frame, .18, meta.detector, {head});
      provider = inference.backend;
      if (!observed && provider !== "wasm") step = fps / 4;
      boxes = inference.boxes.filter(insideField);
      if (yolo && boxes.length < slots.length) {
        const restore = cropField(frame, meta.corners, crop);
        const extra = await detect(crop, .14, meta.detector, {head});
        boxes = suppress([...boxes, ...extra.boxes.map(restore).filter(insideField)]);
      }
    }
    const candidates = boxes.map(box => ({
      xy: project([box.x + box.w / 2, box.y + box.h * .94]),
      appearance: appearance(frame, box), score:box.score,
    })).filter(point => point.xy.every(value => value >= -12 && value <= 156)).slice(0,8);
    const span = indexFrame - previousFrame;
    const found = assign(slots, candidates, (span || step) / fps)
      .map(point=>cameraClear?point:[point[0],point[1],0]);
    found.forEach((point, i) => {
      pointsSeen[i] += point[2] === 1 ? 1 : 0;
      const named = tracks[meta.teams[i].team];
      const position = observed ? point : [...seeds[i], 2];
      const previous = named[previousFrame];
      for (let frameNo = observed ? previousFrame + 1 : 0; frameNo <= indexFrame; frameNo++) {
        const blend = span ? (frameNo - previousFrame) / span : 1;
        named[frameNo] = previous?.[2] && position[2] && distance(previous,position) < 40
          ? [previous[0] + blend*(position[0]-previous[0]), previous[1] + blend*(position[1]-previous[1]), position[2]]
          : frameNo === indexFrame ? position : [...position.slice(0, 2), 0];
      }
    });
    if (indexFrame % (fps / 2) === 0 || indexFrame === last) {
      scoring.read(frame, indexFrame, boxes, found, cameraClear);
    }
    observed++;
    update(observed, Math.ceil(last / step) + 1, provider);
    if (indexFrame === last) break;
    previousFrame = indexFrame;
    // Let the page repaint; the timer keeps analysis going when the window is hidden or minimised.
    if (observed % 4 === 0) await new Promise(resolve => { requestAnimationFrame(resolve); setTimeout(resolve, 50); });
  }
  const trackCoverage = pointsSeen.map(count => Math.round(100 * count / observed));
  if (trackCoverage.filter(coverage => coverage >= 12).length < 3) {
    throw new Error(`The detector found too few team tracks (${trackCoverage.join("%, ")}%). Try Test model on this frame or check the team marks on a clear wide shot.`);
  }
  Object.values(tracks).forEach(rows=>bridgeBriefGaps(rows,fps));
  const replay = scoring.finish(meta, tracks, fps, last, provider);
  replay.robotDetector = meta.detector || "override";
  replay.robotDetectorTrained = Boolean(head);
  replay.robotTrackingVersion = 2;
  replay.trackCoverage = trackCoverage;
  return replay;
}
