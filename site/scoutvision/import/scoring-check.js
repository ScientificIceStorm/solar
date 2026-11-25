// "Check the scoring": after a replay is built, ask the person to grade a few goals and the
// toggles at 7 moments of the match. Each answer becomes a scoring label for this camera
// (the same labels Teach scoring makes), so scoring is trained from every match people check,
// and the replay can be rebuilt with what was learned.

import {access} from "./storage.js?v=load8";
import {analyze, seekFrame} from "./tracking.js?v=load8";
import {goals} from "./scoring.js?v=load8";
import {geometry, OWNER_NAMES, trainScoring, WALLS} from "./scoring-train.js?v=load8";
import {clipId, share, sharingOn} from "./share.js?v=load8";

const ROUNDS = 7;
const WALL_GOALS = {far:["far-neutral", "far-blue"], left:["left-neutral", "left-red"],
  right:["right-blue", "right-neutral"], near:["near-red", "near-neutral"]};
const COLOR_NAMES = ["Red", "Blue", "Yellow"];
const startingCounts = id => id === "midfield" || id.endsWith("neutral") ? [0, 0, 1] : [0, 0, 0];
const clock = seconds => `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;

function stateAt(data, frame) {
  let found = data.states[0];
  for (const state of data.states) {
    if (state[0] > frame) break;
    found = state;
  }
  return found;
}

// One moment just after autonomous, then six spread over driver control. Walls where the
// replay saw the most scoring go first; every other check also asks about the midfield goal.
function plan(data) {
  const {fps, autonomousEnd, driverStart, finalFrame} = data;
  const end = Math.max(driverStart + fps, finalFrame - fps);
  const frames = [Math.min(finalFrame, autonomousEnd + fps),
    ...Array.from({length:ROUNDS - 1}, (_, k) => Math.min(finalFrame, Math.round(driverStart + (k + 1) * (end - driverStart) / (ROUNDS - 1))))];
  const activity = Object.fromEntries(WALLS.map(wall => [wall, data.plays.filter(play =>
    play.wall === wall || play.goals?.some(id => id.startsWith(wall + "-"))).length]));
  const order = [...WALLS].sort((a, b) => activity[b] - activity[a]);
  return frames.map((frame, k) => ({frame, goals:[...WALL_GOALS[order[k % 4]], ...(k % 2 ? ["midfield"] : [])]}));
}

// Draw a crop of the frame, padded, scaled up so stacked pins are easy to count.
function zoom(frame, [left, top, right, bottom], width) {
  const padX = (right - left) * .3, padY = (bottom - top) * .15;
  const x = Math.max(0, left - padX), y = Math.max(0, top - padY);
  const w = Math.min(frame.width, right + padX) - x, h = Math.min(frame.height, bottom + padY) - y;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = Math.max(1, Math.round(width * h / Math.max(1, w)));
  const g = canvas.getContext("2d");
  g.imageSmoothingQuality = "high";
  if (w > 0 && h > 0) g.drawImage(frame, x, y, w, h, 0, 0, canvas.width, canvas.height);
  return canvas;
}

export function setupScoringCheck(ctx) {
  const {$, status} = ctx;
  const card = $("check-card");
  const video = Object.assign(document.createElement("video"), {muted:true, preload:"auto", playsInline:true});
  video.className = "check-video";
  card.append(video);
  const frame = document.createElement("canvas");
  let entry, rounds = [], index = 0, url, answered = 0, shared = 0;

  const say = text => status("check-status", text);
  function buttons(working) {
    for (const id of ["check-save", "check-skip", "check-finish"]) $(id).disabled = working || !entry || index >= rounds.length;
    $("check-rebuild").disabled = working;
    $("check-close").disabled = working;
  }

  function goalTile(id, state) {
    const goalIndex = goals.findIndex(goal => goal.id === id);
    const reading = state?.[2]?.[goalIndex];
    const counts = reading ? reading.slice(0, 3) : startingCounts(id);
    const crop = frame && card.geo.goals.find(goal => goal.id === id).crop;
    const tile = document.createElement("div");
    tile.className = "check-tile";
    const title = document.createElement("strong");
    title.textContent = goals[goalIndex].name;
    tile.append(title, zoom(frame, crop, 170));
    const row = document.createElement("div");
    row.className = "check-counts";
    COLOR_NAMES.forEach((color, c) => {
      const label = document.createElement("label");
      label.className = "score-count score-" + color.toLowerCase();
      const input = Object.assign(document.createElement("input"), {type:"number", min:0, max:12, step:1, value:counts[c]});
      input.dataset.goal = id;
      input.dataset.color = c;
      input.setAttribute("aria-label", `${goals[goalIndex].name} ${color.toLowerCase()} pins`);
      label.append(color[0], input);
      row.append(label);
    });
    const hidden = document.createElement("label");
    hidden.className = "studio-check";
    const box = Object.assign(document.createElement("input"), {type:"checkbox"});
    box.dataset.hidden = id;
    hidden.append(box, " Can't see");
    tile.append(row, hidden);
    return tile;
  }

  function toggleTile(wall, state) {
    const owner = state?.[3]?.[WALLS.indexOf(wall)]?.[0] ?? 0;
    const tile = document.createElement("div");
    tile.className = "check-tile check-toggle";
    const title = document.createElement("strong");
    title.textContent = `${wall[0].toUpperCase() + wall.slice(1)} toggle`;
    const select = document.createElement("select");
    select.dataset.wall = wall;
    select.append(new Option("Can't see", ""), ...OWNER_NAMES.map((name, i) => new Option(name, i)));
    select.value = owner;
    tile.append(title, zoom(frame, card.geo.toggleCrops[wall], 150), select);
    return tile;
  }

  async function show() {
    if (index >= rounds.length) return finish();
    buttons(true);
    const round = rounds[index];
    const seconds = round.frame / entry.data.fps;
    $("check-title").textContent = `Check ${index + 1} of ${rounds.length}`;
    $("check-when").textContent = `${clock(seconds)} into the match`;
    say("Loading this moment…");
    try {
      await seekFrame(video, entry.setup.start + seconds, frame);
      card.geo = geometry(entry.setup.corners, entry.setup.wall, frame.width, frame.height);
      const state = stateAt(entry.data, round.frame);
      $("check-goals").replaceChildren(...round.goals.map(id => goalTile(id, state)));
      $("check-toggles").replaceChildren(...WALLS.map(wall => toggleTile(wall, state)));
      say("Numbers are what the replay read. Fix anything that's wrong, then save.");
    } catch (error) { say(error.message); }
    finally { buttons(false); }
  }

  function answers() {
    const result = {goals:{}, toggles:{}};
    for (const id of rounds[index].goals) {
      result.goals[id] = card.querySelector(`[data-hidden="${id}"]`).checked ? null :
        [0, 1, 2].map(c => Math.max(0, Math.round(+card.querySelector(`[data-goal="${id}"][data-color="${c}"]`).value || 0)));
    }
    for (const wall of WALLS) {
      const value = card.querySelector(`[data-wall="${wall}"]`).value;
      result.toggles[wall] = value === "" ? null : +value;
    }
    return result;
  }

  async function save() {
    buttons(true);
    try {
      const at = +(entry.setup.start + rounds[index].frame / entry.data.fps).toFixed(3);
      const clip = [entry.video.name, entry.video.size, entry.video.lastModified].join(":");
      const id = clip + "#" + at;
      const existing = await access("scoring", "get", id);
      const image = await new Promise(resolve => frame.toBlob(resolve, "image/jpeg", .9));
      if (!image) throw new Error("This video frame could not be saved.");
      const {goals:goalAnswers, toggles} = answers();
      await access("scoring", "put", {id, clip, clipName:entry.video.name, at, image, corners:entry.setup.corners,
        wall:entry.setup.wall, goals:{...existing?.goals, ...goalAnswers}, toggles:{...existing?.toggles, ...toggles}, source:"check"});
      answered++;
      share("scoring", image, {corners:entry.setup.corners, wall:entry.setup.wall, goals:goalAnswers, toggles, at,
        event:entry.event, round:entry.round, teams:entry.data.teams.map(t => t.team), clip:await clipId(clip), source:"check"})
        .then(result => { if (result === "shared") shared++; });
      index++;
      await show();
    } catch (error) { say(error.message); buttons(false); }
  }

  async function finish() {
    index = rounds.length;
    $("check-title").textContent = "Scoring check done";
    $("check-when").textContent = "";
    $("check-goals").replaceChildren();
    $("check-toggles").replaceChildren();
    if (!answered) { say("No answers saved, so nothing was trained."); buttons(false); return; }
    buttons(true);
    $("check-progress").hidden = false;
    try {
      const results = await trainScoring((done, total) => {
        $("check-progress").value = Math.round(100 * done / total);
        say(`Learning from your answers · frame ${done} of ${total}…`);
      });
      const camera = results.find(result => result.name.includes(entry.video.name)) || results[0];
      const check = camera?.validation;
      const describe = ({correct, wrong, unsure}) => `${correct} right, ${wrong} wrong, ${unsure} unsure`;
      say(`Saved ${answered} checks${sharingOn() ? ` (${shared} shared to improve ScoutVision for everyone)` : ""}. ScoutVision now has ${camera?.frames ?? answered} labelled moments for this camera` +
        (check ? ` (self-test on held-out moments · goals: ${describe(check.goals)}; toggles: ${describe(check.toggles)})` : "") +
        ". Rebuild the replay to use them. Every match you check makes this camera more accurate.");
      $("check-after").hidden = false;
    } catch (error) { say(error.message); }
    finally { $("check-progress").hidden = true; buttons(false); }
  }

  async function rebuild() {
    buttons(true);
    ctx.setBusy(true);
    $("check-progress").hidden = false;
    const meta = {...entry.setup, event:entry.event, round:entry.round, teams:entry.data.teams,
      final:entry.data.finalScore ?? null, detector:entry.data.robotDetector || "override", adapted:Boolean(entry.data.robotDetectorTrained),
      clip:[entry.video.name, entry.video.size, entry.video.lastModified].join(":")};
    try {
      const data = await analyze(video, meta, (done, total, backend) => {
        $("check-progress").value = Math.round(100 * done / total);
        say(`Rebuilding with your answers · frame ${done} of ${total} · ${backend}`);
      }, new AbortController().signal);
      entry = {...entry, data, date:Date.now()};
      await access("replays", "put", entry);
      const link = document.createElement("a");
      link.href = "/scoutvision/replay/?id=" + entry.id;
      link.textContent = "Open the rebuilt replay →";
      $("check-status").replaceChildren(link, document.createTextNode(` Scoring: ${data.scoringReference}.`));
      $("check-after").hidden = true;
      ctx.onRebuilt?.();
    } catch (error) { say(error.message); }
    finally { $("check-progress").hidden = true; ctx.setBusy(false); buttons(false); }
  }

  $("check-save").onclick = save;
  $("check-skip").onclick = async () => { index++; await show(); };
  $("check-finish").onclick = finish;
  $("check-rebuild").onclick = rebuild;
  $("check-close").onclick = () => { card.hidden = true; };

  return {
    async open(id) {
      entry = await access("replays", "get", id);
      if (!entry?.video || !entry.setup) throw new Error("This replay was saved without its video, so it can't be checked.");
      if (url) URL.revokeObjectURL(url);
      url = URL.createObjectURL(entry.video);
      video.src = url;
      await new Promise((resolve, reject) => {
        video.onloadedmetadata = resolve;
        video.onerror = () => reject(new Error("This browser could not open the saved video."));
      });
      rounds = plan(entry.data);
      index = 0;
      answered = 0;
      shared = 0;
      $("check-after").hidden = true;
      card.hidden = false;
      card.scrollIntoView({behavior:"smooth", block:"start"});
      await show();
    },
  };
}
