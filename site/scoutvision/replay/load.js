import {access} from "../import/storage.js?v=load9";

const status = document.getElementById("browser-replay-loading");
const key = new URLSearchParams(location.search).get("id");
try {
  if (!/^[\da-f-]{36}$/i.test(key || "")) throw new Error("Choose a saved match from the Match studio.");
  const entry = await access("replays", "get", key);
  if (!entry) throw new Error("This replay is saved in the browser that created it.");
  entry.data.videoFile = URL.createObjectURL(entry.video);
  document.title = entry.event + " · ScoutVision";
  document.getElementById("match-title").textContent = entry.event;
  document.querySelector(".event-context").textContent = "V5RC Override · " + entry.round;
  const rebuild=document.createElement("button");
  rebuild.type="button";
  rebuild.className="play";
  rebuild.textContent="Rebuild replay";
  rebuild.onclick=()=>{ location.href="/scoutvision/import/?rebuild="+key; };
  const note=document.createElement("p");
  note.className="event-context";
  if (!entry.data.scoringVersion) note.append("This saved replay uses earlier scoring. ");
  else if (entry.data.scoringReference) note.append("Scoring calibration · "+entry.data.scoringReference+" ");
  note.append(rebuild);
  document.querySelector(".event-context").after(note);
  document.querySelector(".titlebar").hidden = false;
  document.getElementById("replay-data").textContent = JSON.stringify(entry.data);
  await new Promise((resolve,reject)=>{
    const script=document.createElement("script");
    script.src="/scoutvision/replay/engine.js?v=rebuild";
    script.onload=resolve;
    script.onerror=()=>reject(new Error("Could not load the 3D replay engine."));
    document.body.append(script);
  });
  status.remove();
} catch (error) {
  status.textContent = error.message;
  for (const item of document.querySelectorAll(".metrics-strip,.workspace,#team-analysis,#broadcast")) item.hidden = true;
}
