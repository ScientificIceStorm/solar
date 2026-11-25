// "Teach scoring" card: label goal stacks and toggles on review frames, then train.
import {access} from "./storage.js?v=load9";
import {goals} from "./scoring.js?v=load9";
import {geometry, OWNER_NAMES, trainScoring, WALLS} from "./scoring-train.js?v=load9";
import {clipId, share} from "./share.js?v=load9";

const COLOR_NAMES = ["Red", "Blue", "Yellow"];
const startingCounts = id => id === "midfield" || id.endsWith("neutral") ? [0, 0, 1] : [0, 0, 0];

export function setupScoring(ctx) {
  const {$, status, review} = ctx;
  const preview = $("score-preview");
  const cameras = new Map();
  let saved = [];

  const form = $("score-form");
  form.replaceChildren(...goals.map((goal, index) => {
    const row = document.createElement("div");
    row.className = "score-row";
    const name = document.createElement("span");
    name.textContent = `${index + 1} · ${goal.name}`;
    name.dataset.goalName = goal.id;
    row.append(name, ...COLOR_NAMES.map((color, c) => {
      const label = document.createElement("label");
      label.className = "score-count score-" + color.toLowerCase();
      const input = Object.assign(document.createElement("input"), {type:"number", min:0, max:12, step:1, value:0});
      input.dataset.goal = goal.id;
      input.dataset.color = c;
      input.setAttribute("aria-label", `${goal.name} ${color.toLowerCase()} pins`);
      label.append(color[0], input);
      return label;
    }));
    const hidden = document.createElement("label");
    hidden.className = "studio-check";
    const box = Object.assign(document.createElement("input"), {type:"checkbox"});
    box.dataset.hidden = goal.id;
    hidden.append(box, " Can't see");
    row.append(hidden);
    return row;
  }), ...WALLS.map(wall => {
    const row = document.createElement("div");
    row.className = "score-row";
    const label = document.createElement("label");
    label.className = "studio-field";
    label.textContent = `${wall[0].toUpperCase() + wall.slice(1)} toggle `;
    label.dataset.wallName = wall;
    const select = document.createElement("select");
    select.dataset.wall = wall;
    select.append(new Option("Can't see", ""), ...OWNER_NAMES.map((owner, i) => new Option(owner, i)));
    label.append(select);
    row.append(label);
    return row;
  }));

  const camera = () => cameras.get(ctx.clip()) || {corners:[], wall:$("score-wall").value};
  const read = () => ({
    goals: Object.fromEntries(goals.map(goal => [goal.id,
      form.querySelector(`[data-hidden="${goal.id}"]`).checked ? null :
        [0, 1, 2].map(c => Math.max(0, Math.round(+form.querySelector(`[data-goal="${goal.id}"][data-color="${c}"]`).value || 0)))])),
    toggles: Object.fromEntries(WALLS.map(wall => {
      const value = form.querySelector(`[data-wall="${wall}"]`).value;
      return [wall, value === "" ? null : +value];
    })),
  });
  function fill(label) {
    for (const goal of goals) {
      const counts = label?.goals[goal.id];
      form.querySelector(`[data-hidden="${goal.id}"]`).checked = label ? counts === null : false;
      (counts || startingCounts(goal.id)).forEach((value, c) => {
        form.querySelector(`[data-goal="${goal.id}"][data-color="${c}"]`).value = value;
      });
    }
    for (const wall of WALLS) {
      const owner = label ? label.toggles[wall] : 0;
      form.querySelector(`[data-wall="${wall}"]`).value = owner === null ? "" : owner;
    }
  }

  function draw() {
    if (ctx.at() == null || !review.width) { preview.hidden = true; return; }
    preview.hidden = false;
    preview.width = review.width;
    preview.height = review.height;
    const g = preview.getContext("2d");
    g.drawImage(review, 0, 0);
    const {corners, wall} = camera();
    const {width, height} = preview;
    g.lineWidth = 2;
    g.strokeStyle = "#a7f3af";
    g.fillStyle = "#9aef9d";
    corners.forEach(([x, y], i) => {
      g.beginPath();
      g.arc(x * width, y * height, 5, 0, Math.PI * 2);
      g.fill();
      g.fillText(String(i + 1), x * width + 7, y * height - 5);
    });
    if (corners.length < 4) {
      status("score-mark-status", `Click the ${["top-left", "top-right", "bottom-right", "bottom-left"][corners.length]} inside floor corner (${corners.length + 1} of 4).`);
      return;
    }
    let geo;
    try { geo = geometry(corners, wall, width, height); }
    catch (error) { status("score-mark-status", error.message + " Use Re-mark corners."); return; }
    g.beginPath();
    corners.forEach(([x, y], i) => i ? g.lineTo(x * width, y * height) : g.moveTo(x * width, y * height));
    g.closePath();
    g.stroke();
    g.font = "bold 13px Montserrat, sans-serif";
    geo.goals.forEach((goal, i) => { const row = form.querySelector(`[data-goal-name="${goal.id}"]`); if (row) row.textContent = `${i + 1} · ${goal.name}`; });
    for (const wall of WALLS) { const label = form.querySelector(`[data-wall-name="${wall}"]`); if (label?.firstChild) label.firstChild.textContent = geo.toggleNames[wall] + " "; }
    geo.goals.forEach((goal, i) => {
      const [l, t, r, b] = goal.crop;
      g.strokeStyle = "#ffcf68";
      g.strokeRect(l, t, r - l, b - t);
      g.fillStyle = "#10151b";
      g.fillRect(l, t - 16, 16, 16);
      g.fillStyle = "#ffcf68";
      g.fillText(String(i + 1), l + 4, t - 3);
    });
    g.setLineDash([5, 4]);
    g.strokeStyle = "#6bddff";
    for (const [w, [l, t, r, b]] of Object.entries(geo.toggleCrops)) {
      g.strokeRect(l, t, r - l, b - t);
      g.fillStyle = "#6bddff";
      g.fillText(w, l + 3, b - 4);
    }
    g.setLineDash([]);
    status("score-mark-status", "Check that each numbered box surrounds its goal, then enter what is on it.");
  }

  async function refresh() {
    saved = await access("scoring", "getAll").catch(() => []);
    status("scoring-total", `${saved.length} scoring frame${saved.length === 1 ? "" : "s"} labelled`);
    controls(ctx.isBusy());
  }

  function controls(busy) {
    const ready = ctx.at() != null && camera().corners.length === 4;
    $("save-scoring").disabled = busy || !ready;
    $("train-scoring").disabled = busy || saved.length < 3;
    $("score-reset").disabled = busy || ctx.at() == null;
    $("score-wall").disabled = busy;
  }

  function frameChanged() {
    const clip = ctx.clip();
    if (clip && !cameras.has(clip) && ctx.marks.length >= 4) {
      cameras.set(clip, {corners: ctx.marks.slice(0, 4).map(point => [...point]), wall: ctx.wallSelect.value});
    }
    const current = cameras.get(clip);
    if (current) $("score-wall").value = current.wall;
    const id = clip + "#" + ctx.at();
    const exact = saved.find(item => item.id === id);
    const earlier = saved.filter(item => item.clip === clip && item.at <= ctx.at()).sort((a, b) => b.at - a.at)[0];
    fill(exact || earlier);
    status("scoring-status", exact ? "Showing your saved labels for this frame." :
      earlier ? `Pre-filled from your labels at ${earlier.at}s. Update anything that changed.` : "");
    draw();
    controls(ctx.isBusy());
  }

  preview.onclick = event => {
    const entry = camera();
    if (ctx.isBusy() || entry.corners.length >= 4) return;
    const bounds = preview.getBoundingClientRect();
    entry.corners.push([(event.clientX - bounds.left) / bounds.width, (event.clientY - bounds.top) / bounds.height]);
    cameras.set(ctx.clip(), entry);
    draw();
    controls(ctx.isBusy());
  };
  $("score-reset").onclick = () => {
    cameras.set(ctx.clip(), {corners:[], wall:$("score-wall").value});
    draw();
    controls(ctx.isBusy());
  };
  $("score-wall").onchange = () => {
    const entry = camera();
    entry.wall = $("score-wall").value;
    cameras.set(ctx.clip(), entry);
    draw();
  };

  $("save-scoring").onclick = async () => {
    if (ctx.isBusy()) return;
    const {corners, wall} = camera();
    try { geometry(corners, wall, review.width, review.height); }
    catch (error) { status("scoring-status", error.message); return; }
    ctx.setBusy(true);
    try {
      const image = await new Promise(resolve => review.toBlob(resolve, "image/jpeg", .9));
      if (!image) throw new Error("This video frame could not be saved.");
      const label = {id:ctx.clip() + "#" + ctx.at(), clip:ctx.clip(), clipName:ctx.clipName(), at:ctx.at(),
        image, corners, wall, ...read()};
      await access("scoring", "put", label);
      share("scoring", image, {corners, wall, goals:label.goals, toggles:label.toggles, at:ctx.at(),
        clip:await clipId(ctx.clip()), source:"teach"});
      await refresh();
      status("scoring-status", `${ctx.at()}s · Scoring labels saved.`);
    } catch (error) { status("scoring-status", error.message); }
    finally { ctx.setBusy(false); }
  };

  $("train-scoring").onclick = async () => {
    if (ctx.isBusy()) return;
    ctx.setBusy(true);
    $("scoring-progress").hidden = false;
    try {
      const results = await trainScoring((done, total) => {
        $("scoring-progress").value = Math.round(100 * done / total);
        status("scoring-status", `Reading labelled frame ${done} of ${total}…`);
      });
      const describe = ({correct, wrong, unsure}) => `${correct} right, ${wrong} wrong, ${unsure} unsure`;
      status("scoring-status", results.map(({name, frames, validation}) => `${name}: ${frames} frames. ` +
        (validation ? `Held-out check - goals: ${describe(validation.goals)}; toggles: ${describe(validation.toggles)}.`
          : "Label one more frame from this camera to check accuracy.")).join(" ") +
        " New replays of this camera now use these labels.");
    } catch (error) { status("scoring-status", error.message); }
    finally { $("scoring-progress").hidden = true; ctx.setBusy(false); }
  };

  refresh();
  return {controls, frameChanged};
}
