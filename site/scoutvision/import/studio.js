import {access} from "./storage.js?v=load10";
import {canFineTune, defaultDetector, detect, detectorNames, isYolo, onLoadingStatus} from "./detector.js?v=load10";
import {forgetHead, loadHead, trainDetector} from "./finetune.js?v=load10";
import {analyze, robotPlacement, seekFrame} from "./tracking.js?v=load10";
import {originalScoringReplay} from "./scoring-model.js?v=load10";
import {setupScoring} from "./scoring-studio.js?v=load10";
import {setupScoringCheck} from "./scoring-check.js?v=load10";
import {clipId, setSharing, share, sharingAvailable, sharingOn} from "./share.js?v=load10";

const $ = id => document.getElementById(id);
const video = $("source-video");
const picker = $("video-file");
const markPreview = $("mark-preview"), reviewPreview = $("review-preview");
const marking = document.createElement("canvas"), review = document.createElement("canvas");
const marks = [];
const cornerNames = ["top-left corner", "top-right corner", "bottom-right corner", "bottom-left corner"];
let file, objectUrl, mode = "analyze", busy = false, activeJob, calibratedAt, reviewAt;
let boxes = [], selectedBox = -1, drawing, pendingBox, confirmed = [], fixtures = [];
let officialFinal, officialMatch, scheduleCount = 0;
let rebuilding, scoring, scoringCheck;

const seconds = id => $(id).valueAsNumber;
const rounded = value => +value.toFixed(3);
const point = (event, canvas) => {
  const bounds = canvas.getBoundingClientRect();
  return [Math.max(0,Math.min(1,(event.clientX-bounds.left)/bounds.width)),
    Math.max(0,Math.min(1,(event.clientY-bounds.top)/bounds.height))];
};
const sourceKey = () => file && [file.name,file.size,file.lastModified].join(":");
const boxID = () => sourceKey() + "#" + reviewAt;
const ready = () => file && video.readyState >= 1;
const names = () => Array.from({length:4}, (_,i) => $("team-" + i).value.trim().toUpperCase());
const backendLabel = backend => ({webgl:"WebGL", webgpu:"WebGPU", wasm:"CPU"})[backend] || backend;
const status = (id, text) => { $(id).textContent = text; };
const autoYolo = () => defaultDetector;
const selectedDetector = () => $("detector-choice").value === "auto" ? autoYolo() : $("detector-choice").value;
const trainingDetector = () => canFineTune(selectedDetector()) ? selectedDetector() : defaultDetector;
const trainedHeads = {};
async function refreshHeads() {
  for (const choice of Object.keys(detectorNames).filter(canFineTune)) {
    trainedHeads[choice] = await loadHead(choice).catch(() => null);
  }
  showDetector();
}
const activeHead = choice => isYolo(choice) && $("adapted").checked ? trainedHeads[choice] || null : null;
function showDetector() {
  const chosen = selectedDetector(), head = trainedHeads[chosen];
  status("detector-status", head
    ? `${detectorNames[chosen]} + your training from ${head.frames} reviewed frames.`
    : `${detectorNames[chosen]} is built in and ready to use.`);
  $("train").textContent = `Train ${detectorNames[trainingDetector()]}`;
  const saved = trainedHeads[trainingDetector()];
  $("forget-training").hidden = !saved;
  if (saved) {
    const {base, trained, frames} = saved.validation;
    status("training-saved", `Saved training: found ${trained.matched}/${trained.expected} robots on ${frames} held-out frames ` +
      `(base model ${base.matched}/${base.expected}).`);
  } else status("training-saved", "");
  controls();
}
$("detector-choice").onchange = showDetector;
$("event").oninput = showDetector;

function controls() {
  picker.disabled = busy;
  $("detector-choice").disabled = busy;
  const custom = Boolean(trainedHeads[selectedDetector()]);
  $("adapted-option").hidden = !custom;
  $("adapted").disabled = busy || !custom;
  $("forget-training").disabled = busy;
  $("export-labels").disabled = busy || !confirmed.length;
  scoring?.controls(busy);
  $("mode-analyze").disabled = $("mode-review").disabled = busy;
  $("load-frame").disabled = $("review-frame").disabled = $("test-frame").disabled =
    $("review-next").disabled = busy || !ready();
  $("undo").disabled = $("reset-marks").disabled = busy || !marks.length;
  $("analyze").disabled = busy || marks.length !== 8 || calibratedAt !== seconds("start");
  $("remove-box").disabled = busy || selectedBox < 0;
  $("clear-boxes").disabled = busy || !boxes.length;
  $("save-label").disabled = busy || reviewAt == null;
  $("train").disabled = busy || confirmed.length < 8 || confirmed.filter(item => item.boxes.length).length < 6;
  $("stop").hidden = !activeJob;
}

function selectMode(next) {
  mode = next;
  for (const value of ["analyze","review"]) {
    $("mode-" + value).setAttribute("aria-pressed",String(value===next));
  }
  $("match-form").hidden = $("mark-card").hidden = next === "review";
  $("training-card").hidden = $("review-card").hidden = $("scoring-card").hidden = next !== "review";
}
$("mode-analyze").onclick = () => selectMode("analyze");
$("mode-review").onclick = () => selectMode("review");

picker.onchange = () => {
  rebuilding = undefined;
  openVideo(picker.files[0]);
};
function openVideo(chosen) {
  if (objectUrl) URL.revokeObjectURL(objectUrl);
  file = chosen;
  marks.length = 0;
  boxes = [];
  calibratedAt = reviewAt = undefined;
  selectedBox = -1;
  reviewPreview.hidden = markPreview.hidden = true;
  $("mark-placeholder").hidden = false;
  $("original-scoring").hidden = true;
  video.hidden = $("set-times").hidden = true;
  status("mark-status", "");
  status("review-status", "");
  status("run-status", "");
  if (!file) {
    video.removeAttribute("src");
    video.load();
    status("file-status", "");
  } else {
    status("file-status", "Opening video…");
    objectUrl = URL.createObjectURL(file);
    video.src = objectUrl;
    originalScoringReplay(chosen).then(match=>{
      if (!match || file!==chosen) return;
      const link=$("open-original-replay");
      link.href=match.recording.path;
      link.textContent=`Open original ${match.name} scoring replay`;
      $("original-scoring").hidden=false;
    }).catch(()=>{});
  }
  controls();
  showDetector();
}
video.onloadedmetadata = async () => {
  if (!Number.isFinite(video.duration) || video.duration < 1) {
    status("file-status", "Choose a video with a readable duration.");
    return;
  }
  video.hidden = $("set-times").hidden = false;
  $("start").value = 0;
  $("driver").value = Math.min(15, rounded(video.duration));
  $("end").value = Math.min(120, rounded(video.duration));
  if (rebuilding) {
    const {entry, setup} = rebuilding;
    $("start").value = setup?.start ?? (Number(entry.data.videoOffset) || 0);
    $("driver").value = setup?.driver ?? rounded(seconds("start") + entry.data.driverStart / entry.data.fps);
    $("end").value = Math.min(video.duration, setup?.end ?? rounded(seconds("start") + entry.data.driverEnd / entry.data.fps));
    if (setup) {
      $("red-wall").value = setup.wall;
      try {
        await seekFrame(video, seconds("start"), marking);
        marks.push(...setup.corners,...setup.robots);
        calibratedAt = seconds("start");
        drawMarks();
      } catch (error) { status("mark-status", error.message); }
    }
    status("run-status", setup ? "Match setup restored. Build a new replay with YOLO and the scoring references." :
      "Saved video and teams restored. Mark the four corners and robots to rebuild.");
  }
  status("file-status", `${file.name} · ${Math.round(video.duration)} seconds`);
  controls();
};
video.onerror = () => {
  video.hidden = true;
  status("file-status", "This browser could not open that video. Try an H.264 MP4 or WebM.");
  controls();
};
video.addEventListener("play", () => { if (busy) video.pause(); });

function timingChanged() {
  if (!ready()) return;
  $("driver").value = rounded(Math.min(seconds("start")+15,video.duration));
  $("end").value = rounded(Math.min(seconds("start")+120,video.duration));
  drawMarks();
}
$("start").addEventListener("change",timingChanged);
$("start").addEventListener("input",drawMarks);
for (const button of document.querySelectorAll("[data-time]")) {
  button.onclick = () => {
    if (busy || !ready()) return;
    $(button.dataset.time).value = rounded(video.currentTime);
    if (button.dataset.time==="start") timingChanged();
  };
}

function showFrame(from, into) {
  if (into.width !== from.width || into.height !== from.height) {
    into.width = from.width;
    into.height = from.height;
  }
  const ctx = into.getContext("2d");
  ctx.drawImage(from,0,0);
  return ctx;
}

function drawMarks() {
  controls();
  if (calibratedAt == null) return;
  const ctx = showFrame(marking,markPreview);
  const {width,height} = markPreview;
  markPreview.hidden = false;
  $("mark-placeholder").hidden = true;
  ctx.lineWidth = 2;
  ctx.strokeStyle = "#a7f3af";
  if (marks.length > 1) {
    ctx.beginPath();
    marks.slice(0,4).forEach(([x,y],i)=> i ? ctx.lineTo(x*width,y*height) : ctx.moveTo(x*width,y*height));
    if (marks.length>=4) ctx.closePath();
    ctx.stroke();
  }
  marks.forEach(([x,y],i)=>{
    ctx.fillStyle = i<4?"#9aef9d":i<6?"#ff8c83":"#6bddff";
    ctx.strokeStyle = "#10151b";
    ctx.beginPath();
    ctx.arc(x*width,y*height,6,0,Math.PI*2);
    ctx.fill();
    ctx.stroke();
    ctx.font = "bold 13px Montserrat, sans-serif";
    const label = i<4?i+1:names()[i-4] || `Robot ${i-3}`;
    ctx.strokeText(label,x*width+9,y*height-6);
    ctx.fillText(label,x*width+9,y*height-6);
  });
  const i = marks.length;
  const name = i<4 ? cornerNames[i] : (names()[i-4] || (i<6?`red team ${i-3}`:`blue team ${i-5}`));
  // Check robot marks against the outline as soon as they are clicked, not after Build.
  let check = "";
  if (i > 4) {
    const placed = robotPlacement({corners:marks.slice(0,4), robots:marks.slice(4), wall:$("red-wall").value,
      teams:names().map((team,k)=>({team:team || `Robot ${k+1}`}))});
    check = placed.problem ? ` ⚠ ${placed.problem}` : placed.notes.length ? ` Note: ${placed.notes.join("; ")}.` : "";
  }
  status("mark-status",calibratedAt!==seconds("start")?"Start time changed. Load the new frame.":i===8?
    `Field and robots marked. Build the replay when ready.${check}`:`Mark ${i+1} of 8 · ${name}.${check}`);
}
$("load-frame").onclick = async () => {
  if (!ready() || busy) return;
  const at = seconds("start");
  if (!(at >= 0 && at < video.duration)) return status("mark-status","Enter a start time within the video.");
  busy = true; controls(); video.pause();
  try {
    await seekFrame(video,at,marking);
    if (at!==calibratedAt) marks.length=0;
    calibratedAt=at;
  } catch (error) { status("mark-status",error.message); }
  finally { busy=false; drawMarks(); }
};
markPreview.onclick = event => {
  if (busy || marks.length>=8 || calibratedAt!==seconds("start")) return;
  marks.push(point(event,markPreview));
  drawMarks();
};
$("undo").onclick = () => { marks.pop(); drawMarks(); };
$("reset-marks").onclick = () => { marks.length=0; drawMarks(); };
["team-0","team-1","team-2","team-3"].forEach(id=>$(id).oninput=drawMarks);

async function loadSchedule(division="") {
  const sku=$("event-link").value.match(/(?:RE-V5RC|VE-V5)-\d{2}-\d+/i)?.[0];
  if (!sku) return status("schedule-status","Paste a V5RC event link or enter its SKU.");
  const request=++scheduleCount;
  $("find-schedule").disabled=true;
  status("schedule-status","Loading the posted schedule…");
  try {
    const query=new URLSearchParams({sku});
    if (division) query.set("division",division);
    const response=await fetch("/api/event?"+query);
    if (!response.ok) throw new Error();
    const data=await response.json();
    if (request!==scheduleCount) return;
    fixtures=data.matches || [];
    $("event").value=data.event.name;
    showDetector();
    $("division").replaceChildren(new Option("Default division",""),
      ...(data.event.divisions || []).map(row=>new Option(row.name,row.id)));
    $("division").value=division;
    $("scheduled-match").replaceChildren(new Option("Select match",""),...fixtures.map((row,i)=>new Option(row.name,i)));
    $("schedule").hidden=false;
    status("schedule-status",fixtures.length?"":"No matches posted in this division yet. Enter the lineup below.");
  } catch { if(request===scheduleCount) status("schedule-status","Schedule unavailable. Enter the match details below."); }
  finally { $("find-schedule").disabled=false; }
}
$("find-schedule").onclick=()=>loadSchedule();
$("division").onchange=()=>loadSchedule($("division").value);
$("event-link").oninput=()=>{
  scheduleCount++;
  $("schedule").hidden=true;
  officialMatch=officialFinal=undefined;
};
$("scheduled-match").onchange=()=>{
  const row=fixtures[$("scheduled-match").value];
  if (!row) return;
  $("round").value=row.name;
  const alliances=["red","blue"].map(color=>row.alliances.find(side=>side.color.toLowerCase()===color));
  alliances.forEach((side,i)=>{
    for (let j=0;j<2;j++) $("team-"+(2*i+j)).value=side?.teams?.[j]?.number || "";
  });
  officialMatch={round:row.name, event:$("event").value, names:names().join()};
  officialFinal=row.completed && alliances.every(side=>Number.isInteger(side?.score))?alliances.map(side=>side.score):null;
  drawMarks();
};

function metadata() {
  const start=seconds("start"), driver=seconds("driver"),end=seconds("end");
  const selected=names();
  if (start<0 || !(start+14.9<=driver && driver<end && end<=video.duration+.03) || end-start>240) {
    throw new Error("Choose a clip up to four minutes and set the actual starts of autonomous and driver control.");
  }
  if (new Set(selected).size!==4 || !selected.every(name=>/^\d{1,7}[A-Z]{0,2}$/.test(name))) {
    throw new Error("Enter four different VEX team numbers.");
  }
  const event=$("event").value.trim(), round=$("round").value.trim();
  if (!event || !round) throw new Error("Enter an event name and match label.");
  const final=officialMatch?.event===event && officialMatch.round===round && officialMatch.names===selected.join()?officialFinal:null;
  return {start,driver,end:Math.min(end,video.duration), event, round, final,
    teams:selected.map((team,i)=>({team,alliance:i<2?"red":"blue"})),
    wall:$("red-wall").value,corners:marks.slice(0,4),robots:marks.slice(4),detector:selectedDetector(),
    adapted:Boolean(activeHead(selectedDetector())), clip:sourceKey()};
}

$("match-form").onsubmit=async event=>{
  event.preventDefault();
  if (busy || !ready() || marks.length!==8 || calibratedAt!==seconds("start")) return;
  let meta;
  try { meta=metadata(); } catch(error) { status("run-status",error.message); return; }
  busy=true;
  activeJob=new AbortController();
  const current=activeJob;
  controls();
  video.pause();
  $("progress").hidden=false;
  $("progress").value=0;
  status("run-status",`Loading ${detectorNames[meta.detector]}…`);
  // Until the first frame is analysed, show the current step and how long it has taken, so a
  // stall says exactly where it is.
  let step=$("run-status").textContent, stepStarted=Date.now();
  const ticker=setInterval(()=>{
    if (!/^Analyzing/.test($("run-status").textContent)) status("run-status",`${step} (${Math.round((Date.now()-stepStarted)/1000)} s)`);
  },1000);
  onLoadingStatus(text=>{ if (text.split(":")[0]!==step.split(":")[0]) stepStarted=Date.now(); step=text; status("run-status",text); });
  try {
    const data=await analyze(video,meta,(done,total,backend)=>{
      $("progress").value=Math.round(done/total*100);
      status("run-status",`Analyzing frame ${done} of ${total} · ${backendLabel(backend)}`);
    },current.signal);
    const id=crypto.randomUUID();
    const setup={start:meta.start, driver:meta.driver, end:meta.end, wall:meta.wall, corners:meta.corners, robots:meta.robots};
    await access("replays","put",{id,event:meta.event,round:meta.round,date:Date.now(),video:file,data,setup});
    await refreshLibrary();
    const link=document.createElement("a");
    link.href="/scoutvision/replay/?id="+id;
    link.textContent="Open 3D replay →";
    $("run-status").replaceChildren(link, document.createTextNode(" · Check the scoring below to make it more accurate."));
    scoringCheck.open(id).catch(error=>status("check-status",error.message));
  } catch(error) {
    status("run-status",current.signal.aborted?"Analysis canceled.":error.name==="QuotaExceededError"?
      "The browser is out of storage. Remove an imported replay or choose a smaller video.":error.message);
  } finally {
    clearInterval(ticker);
    onLoadingStatus(null);
    activeJob=undefined; busy=false;
    $("progress").hidden=true;
    controls();
  }
};
$("stop").onclick=()=>activeJob?.abort(new Error("Canceled"));

function drawReview(){
  controls();
  if (reviewAt==null) return;
  reviewPreview.hidden=false;
  const ctx=showFrame(review,reviewPreview);
  const {width,height}=reviewPreview;
  ctx.lineWidth=2;
  for (const [i,box] of [...boxes,...(pendingBox?[pendingBox]:[])].entries()) {
    ctx.strokeStyle=i===selectedBox?"#ffcf68":"#8bffad";
    ctx.strokeRect(box.x*width,box.y*height,box.w*width,box.h*height);
    if (typeof box.score === "number") {
      const text = `Robot ${Math.round(box.score * 100)}%`;
      ctx.font = "600 12px Montserrat, sans-serif";
      const top = Math.max(0, box.y*height - 18);
      ctx.fillStyle = "#0d141a";
      ctx.fillRect(box.x*width, top, ctx.measureText(text).width + 8, 18);
      ctx.fillStyle = ctx.strokeStyle;
      ctx.fillText(text, box.x*width + 4, top + 13);
    }
  }
}
async function reviewFrame(at, test = false){
  if (busy || !ready()) return;
  busy=true; controls(); video.pause();
  status("review-status","Detecting visible robots…");
  try {
    reviewAt=rounded(Math.min(at,Math.max(0,video.duration-.04)));
    selectedBox=-1; pendingBox=undefined; boxes=[];
    await seekFrame(video,reviewAt,review);
    const saved=test ? null : await access("labels","get",boxID());
    if (saved) {
      boxes=saved.boxes;
      status("review-status",`${reviewAt}s · Saved review`);
    } else {
      const selected=selectedDetector();
      status("review-status",`Loading ${detectorNames[selected]}…`);
      onLoadingStatus(text=>status("review-status",text));
      const head = activeHead(selected);
      const result=await detect(review, .18, selected, {head});
      boxes=result.boxes;
      status("review-status",`${reviewAt}s · ${boxes.length} suggestions · ${detectorNames[selected]}${head?" + your training":""} · ${backendLabel(result.backend)}`);
    }
  } catch(error) { status("review-status",error.message); }
  finally { onLoadingStatus(null); busy=false; drawReview(); scoring?.frameChanged(); }
}
$("review-frame").onclick=()=>reviewFrame(video.currentTime);
$("test-frame").onclick=()=>reviewFrame(video.currentTime, true);
$("review-next").onclick=()=>reviewFrame((reviewAt??video.currentTime)+3);
reviewPreview.onpointerdown=event=>{
  if (busy || reviewAt==null) return;
  drawing=point(event,reviewPreview);
  reviewPreview.setPointerCapture(event.pointerId);
};
reviewPreview.onpointermove=event=>{
  if (!drawing) return;
  const [x,y]=point(event,reviewPreview);
  const [a,b]=drawing;
  pendingBox={x:Math.min(x,a),y:Math.min(y,b),w:Math.abs(x-a),h:Math.abs(y-b)};
  drawReview();
};
reviewPreview.onpointerup=event=>{
  if (!drawing) return;
  const [x,y]=point(event,reviewPreview);
  if (pendingBox && pendingBox.w>.013 && pendingBox.h>.025) selectedBox=boxes.push(pendingBox)-1;
  else selectedBox=boxes.findLastIndex(box=>x>=box.x && x<=box.x+box.w && y>=box.y && y<=box.y+box.h);
  drawing=pendingBox=undefined; drawReview();
};
reviewPreview.onpointercancel=()=>{ drawing=pendingBox=undefined; drawReview(); };
$("remove-box").onclick=()=>{ if(selectedBox>=0) boxes.splice(selectedBox,1); selectedBox=-1; drawReview(); };
$("clear-boxes").onclick=()=>{ boxes=[]; selectedBox=-1; drawReview(); };

async function labels(){
  confirmed=await access("labels","getAll");
  status("label-total",`${confirmed.length} reviewed frame${confirmed.length===1?"":"s"}`);
  controls();
}
$("save-label").onclick=async()=>{
  if (busy || reviewAt==null) return;
  busy=true; controls();
  try {
    const image=await new Promise(resolve=>review.toBlob(resolve,"image/jpeg",.84));
    if(!image) throw new Error("This video frame could not be saved.");
    await access("labels","put",{id:boxID(),clip:sourceKey(),at:reviewAt,image,boxes:boxes.map(({x,y,w,h})=>({x,y,w,h}))});
    share("robots",image,{boxes:boxes.map(({x,y,w,h})=>({x,y,w,h})),at:reviewAt,clip:await clipId(sourceKey()),source:"review"});
    status("review-status",`${reviewAt}s · Saved ${boxes.length} robot boxes`);
    await labels();
  } catch(error) { status("review-status",error.message); }
  finally { busy=false; controls(); }
};
$("train").onclick=async()=>{
  if (busy || $("train").disabled) return;
  const choice = trainingDetector();
  busy=true; controls();
  $("training-progress").value=0;
  $("training-progress").hidden=false;
  status("training-status","Preparing reviewed frames…");
  onLoadingStatus(text=>status("training-status",text));
  try {
    const result=await trainDetector(confirmed,choice,(stage,done,total,backend)=>{
      $("training-progress").value=Math.round(100 * done / (total || 1));
      status("training-status",`${stage} · ${done} of ${total} · ${backendLabel(backend)}`);
    });
    const where = `${result.checked} held-out ${result.heldOutClip?"frames from another video":"frames"}`;
    const base = `Base model: ${result.base.matched}/${result.base.expected} robots found, ${result.base.detected-result.base.matched} false alarms.`;
    if (result.saved) {
      $("detector-choice").value=choice;
      $("adapted").checked=true;
      await refreshHeads();
      status("training-status",`Trained on ${result.frames} frames and saved in this browser. On ${where} it found ` +
        `${result.trained.matched}/${result.trained.expected} robots with ${result.trained.detected-result.trained.matched} false alarms. ${base}`);
    } else {
      status("training-status",`Training did not beat the base model on ${where}, so nothing was saved. ${base} ` +
        "Review more frames where the model misses robots, then train again.");
    }
  } catch(error) { status("training-status",error.message); }
  finally { onLoadingStatus(null); busy=false; $("training-progress").hidden=true; controls(); }
};
$("forget-training").onclick=async()=>{
  const choice=trainingDetector();
  if (busy || !confirm(`Remove your training for ${detectorNames[choice]} from this browser? Your reviewed frames stay saved.`)) return;
  try { await forgetHead(choice); await refreshHeads(); status("training-status","Your training was removed. The base model is in use."); }
  catch(error) { status("training-status",error.message); }
};
$("export-labels").onclick=async()=>{
  if (busy || !confirmed.length) return;
  busy=true; controls();
  try {
    const frames=[];
    for (const item of confirmed) {
      const bytes=new Uint8Array(await item.image.arrayBuffer());
      let text="";
      for (let i=0;i<bytes.length;i+=32768) text+=String.fromCharCode(...bytes.subarray(i,i+32768));
      frames.push({clip:item.clip, at:item.at, boxes:item.boxes, jpeg:btoa(text)});
    }
    const blob=new Blob([JSON.stringify({format:"scoutvision-robot-labels",version:1,frames})],{type:"application/json"});
    const link=document.createElement("a");
    link.href=URL.createObjectURL(blob);
    link.download=`scoutvision-robot-labels-${new Date().toISOString().slice(0,10)}.json`;
    link.click();
    setTimeout(()=>URL.revokeObjectURL(link.href),2000);
    status("training-status",`Downloaded ${frames.length} reviewed frames for GPU retraining.`);
  } catch(error) { status("training-status",error.message); }
  finally { busy=false; controls(); }
};

async function refreshLibrary(){
  try {
    const items=(await access("replays","getAll")).sort((a,b)=>b.date-a.date);
    $("library").replaceChildren(...items.map(({id,event,round,data})=>{
      const row=document.createElement("li"), info=document.createElement("div");
      const link=document.createElement("a"), detail=document.createElement("small");
      link.href="/scoutvision/replay/?id="+id;
      link.textContent=event;
      detail.textContent=round + (!data.scoringVersion ? " · Earlier scoring" : "");
      const actions=document.createElement("div"), rebuild=document.createElement("a");
      actions.className="library-actions";
      rebuild.href="?rebuild="+id;
      rebuild.className="sv-primary";
      rebuild.textContent="Rebuild replay";
      const remove=document.createElement("button");
      remove.type="button"; remove.textContent="Remove"; remove.className="sv-secondary";
      remove.onclick=async()=>{
        if (!confirm(`Remove the browser copy of ${event} · ${round}?`)) return;
        try { await access("replays","delete",id); await refreshLibrary(); }
        catch(error) { status("library-status",error.message); }
      };
      const check=document.createElement("button");
      check.type="button"; check.textContent="Check scoring"; check.className="sv-secondary";
      check.onclick=()=>scoringCheck.open(id).catch(error=>status("library-status",error.message));
      info.append(link,detail); actions.append(rebuild,check,remove); row.append(info,actions);
      return row;
    }));
    status("library-status",items.length?"":"No browser replays saved yet.");
  } catch { status("library-status","Browser storage is unavailable."); }
}

async function restoreReplay(id) {
  try {
    const entry = await access("replays","get",id);
    if (!entry?.video) throw new Error("This replay is saved in the browser that created it.");
    rebuilding = {entry, setup:entry.setup};
    $("event").value = entry.event;
    $("round").value = entry.round;
    entry.data.teams.forEach((team,i)=>{ $("team-"+i).value=team.team; });
    officialMatch={event:entry.event,round:entry.round,names:names().join()};
    officialFinal=entry.data.finalScore;
    $("detector-choice").value="auto";
    openVideo(entry.video);
  } catch (error) { status("run-status",error.message); }
}

refreshLibrary();
labels().catch(()=>status("training-status","Browser storage is unavailable."));
const params = new URLSearchParams(location.search);
if (params.get("mode") === "train") selectMode("review");
if (params.has("rebuild")) restoreReplay(params.get("rebuild"));
$("find-schedule").disabled = false;
scoring = setupScoring({
  $, status, review, video, isBusy:()=>busy, setBusy:value=>{ busy=value; controls(); },
  clip:()=>sourceKey(), clipName:()=>file?.name, at:()=>reviewAt, marks, wallSelect:$("red-wall"),
});
scoringCheck = setupScoringCheck({$, status, setBusy:value=>{ busy=value; controls(); }, onRebuilt:refreshLibrary});
$("share-option").hidden = true;
sharingAvailable().then(ready => { $("share-option").hidden = !ready; $("share-data").checked = sharingOn(); });
$("share-data").onchange = () => setSharing($("share-data").checked);
controls();
showDetector();
refreshHeads();
