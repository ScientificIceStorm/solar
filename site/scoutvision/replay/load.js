import {access} from "../import/storage.js?v=load10";

// Two kinds of replay open here:
//   ?id=<uuid>     a replay saved in this browser by the Match studio (with its video file);
//   ?match=<uuid>  an analysis published on Solar (no video file: the broadcast panel plays the
//                  event's YouTube stream at that match when Solar knows where it is).
const status = document.getElementById("browser-replay-loading");
const params = new URLSearchParams(location.search);
const key = params.get("id"), published = params.get("match");
const uuid = /^[\da-f-]{36}$/i;

// The YouTube link Solar has for a match: {id, seconds into the video ~35 s before it starts}.
async function matchVideo(meta) {
  if (!Number.isInteger(meta.matchId)) return null;
  try {
    const query = new URLSearchParams({sku: meta.sku, division: String(meta.division || 1), streams: "1"});
    const links = await (await fetch("/api/event?" + query)).json();
    const link = new URL(links[meta.matchId]);
    const id = link.pathname.split("/").pop();
    const start = Number(link.searchParams.get("start"));
    return /youtube/.test(link.hostname) && /^[\w-]{11}$/.test(id) && Number.isFinite(start) ? {id, start} : null;
  } catch { return null; }
}

function titlebar(event, round, extra) {
  document.title = event + " · ScoutVision";
  document.getElementById("match-title").textContent = event;
  document.querySelector(".event-context").textContent = "V5RC Override · " + round;
  if (extra) document.querySelector(".event-context").after(extra);
  document.querySelector(".titlebar").hidden = false;
}

try {
  let data;
  if (published) {
    if (!uuid.test(published)) throw new Error("This analysis link is not valid.");
    const response = await fetch("/api/scoutvision/matches/" + published);
    if (!response.ok) throw new Error(response.status === 404 ? "This analysis was not found." : "Solar could not load this analysis.");
    const record = await response.json();
    const meta = record.meta;
    data = record.replay;
    data.finalScore = meta.official || data.finalScore;
    data.videoFile = "";
    const video = await matchVideo(meta);
    if (video) {
      // Replay time 0 is the start of autonomous; Solar's links open ~35 s before the match starts.
      data.youtube = {id: video.id, label: "Open on YouTube ↗"};
      data.videoOffset = video.start + 35;
    }
    const note = document.createElement("p");
    note.className = "event-context";
    note.append("Published analysis" + (meta.source === "vexvision" ? " (ScoutVision import)" : "") + " · " +
      new Date(record.publishedAt).toLocaleDateString());
    if (!meta.teamsConfirmed) note.append(" · Alliances are right; which robot is which team within an alliance is not confirmed.");
    if (!video) note.append(" · No broadcast found for this match.");
    const page = document.createElement("a");
    page.href = "/event/" + encodeURIComponent(meta.sku);
    page.textContent = " Event page →";
    note.append(page);
    titlebar(meta.eventName, meta.round, note);
    if (!video) document.getElementById("broadcast").hidden = true;
  } else {
    if (!uuid.test(key || "")) throw new Error("Choose a saved match from the Match studio.");
    const entry = await access("replays", "get", key);
    if (!entry) throw new Error("This replay is saved in the browser that created it.");
    entry.data.videoFile = URL.createObjectURL(entry.video);
    const rebuild = document.createElement("button");
    rebuild.type = "button";
    rebuild.className = "play";
    rebuild.textContent = "Rebuild replay";
    rebuild.onclick = () => { location.href = "/scoutvision/import/?rebuild=" + key; };
    const note = document.createElement("p");
    note.className = "event-context";
    if (!entry.data.scoringVersion) note.append("This saved replay uses earlier scoring. ");
    else if (entry.data.scoringReference) note.append("Scoring calibration · " + entry.data.scoringReference + " ");
    note.append(rebuild);
    titlebar(entry.event, entry.round, note);
    data = entry.data;
  }
  document.getElementById("replay-data").textContent = JSON.stringify(data);
  await new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = "/scoutvision/replay/engine.js?v=stats-4";
    script.onload = resolve;
    script.onerror = () => reject(new Error("Could not load the 3D replay engine."));
    document.body.append(script);
  });
  status.remove();
} catch (error) {
  status.textContent = error.message;
  for (const item of document.querySelectorAll(".metrics-strip,.workspace,#team-analysis,#match-stats,#broadcast")) item.hidden = true;
}
