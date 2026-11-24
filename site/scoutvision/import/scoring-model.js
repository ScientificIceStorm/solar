import {access} from "./storage.js?v=load3";

const COLORS = ["red", "blue", "yellow"];
const OWNERS = {unknown:null, neutral:0, red:1, blue:2};
const COLS = 14, ROWS = 24;
let loading;

export const decodeValues = data => Uint8Array.from(atob(data), value => value.charCodeAt(0));

// Built-in cameras (Smoky, Mall of America, Highlander, Speedway) plus any scoring camera
// trained in this browser from labelled frames (see scoring-train.js).
export function scoringReferences() {
  loading ||= Promise.all(["goal-references-v1.json","speedway-scoring-camera.json"].map(async file=>{
    const response=await fetch("/scoutvision/assets/"+file);
    if (!response.ok) throw new Error("Could not open the scoring references. Try again.");
    return response.json();
  })).then(async ([model,speedway])=>{
    model.cameras.push(speedway);
    const trained=(await access("models","getAll").catch(()=>[])).filter(item=>item.kind==="scoring-camera");
    model.cameras.push(...trained.map(camera=>structuredClone(camera)));
    for (const camera of model.cameras) {
      for (const [goal, examples] of Object.entries(camera.references)) {
        camera.references[goal] = examples.map(([counts, data]) => ({counts, values:decodeValues(data)}));
      }
      for (const [wall, examples] of Object.entries(camera.toggleReferences || {})) {
        camera.toggleReferences[wall] = examples.map(([owner, data]) => ({owner, values:decodeValues(data)}));
      }
    }
    return model;
  }).catch(error=>{ loading=undefined; throw error; });
  return loading;
}

export function resetScoringReferences() { loading = undefined; }

export async function originalScoringReplay(file) {
  const {cameras} = await scoringReferences();
  const possible=cameras.filter(camera=>camera.recording?.bytes===file.size);
  if (!possible.length || !globalThis.crypto.subtle) return null;
  const bytes=await crypto.subtle.digest("SHA-256",await file.arrayBuffer());
  const key=Array.from(new Uint8Array(bytes),value=>value.toString(16).padStart(2,"0")).join("");
  return possible.find(camera=>camera.recording.sha256===key) || null;
}

export function pixelReader(canvas) {
  const {width,height}=canvas;
  const {data}=canvas.getContext("2d").getImageData(0,0,width,height);
  return (x,y) => {
    x=Math.round(x); y=Math.round(y);
    if (x<0 || y<0 || x>=width || y>=height) return [0,0,0,0];
    const index=(y*width+x)*4;
    const r=data[index], g=data[index+1], b=data[index+2];
    const v=Math.max(r,g,b), d=v-Math.min(r,g,b);
    const angle=d ? (v===r ? (g-b)/d : v===g ? 2+(b-r)/d : 4+(r-g)/d)*30 : 0;
    const h=(angle+180)%180;
    return [h,v ? 255*d/v : 0,v,.299*r+.587*g+.114*b];
  };
}

function color(pixel, kind) {
  const [h,s,v]=pixel;
  if (kind==="dark") return +(v<110 && v>0);
  if (s<=65 || v<=85) return 0;
  return +(kind==="red" ? h<=11 || h>=153 : kind==="blue" ? h>=85 && h<=133 : h>=14 && h<=44);
}

export function blocked(x,y,boxes,width,height) {
  return boxes.some(box=>x/width>=box.x && x/width<=box.x+box.w &&
    y/height>=box.y && y/height<=box.y+box.h);
}

function bands(read, spec, map, boxes, width, height) {
  const {base_patch:[left,top,right,bottom], base_color, x, mouth, slope, roof}=spec;
  const center=map([(left+right)/2,(top+bottom)/2]);
  let base=0, pixels=0;
  for (let row=top;row<bottom;row+=2) for (let col=left;col<right;col+=2) {
    base+=color(read(...map([col,row])),base_color);
    pixels++;
  }
  const baseStrength=pixels ? base/pixels : 0;
  const overlaps=blocked(...center,boxes,width,height);
  if (baseStrength<(overlaps ? .62 : spec.base_min ?? .39)) return null;
  const runs=[];
  for (const hue of spec.colors) {
    const strip=[];
    for (let row=roof;row<=mouth;row++) {
      let coverage=0;
      const cx=x+slope*(mouth-row);
      for (let dx=-spec.width;dx<=spec.width;dx++) coverage+=color(read(...map([cx+dx,row])),hue);
      strip.push(coverage/(2*spec.width+1)>=(spec.color_min ?? .32));
    }
    for (let i=1;i<strip.length-1;i++) if (!strip[i] && strip[i-1] && strip[i+1]) strip[i]=true;
    let start=-1;
    for (let i=0;i<=strip.length;i++) {
      if (strip[i] && start<0) start=i;
      if (strip[i] || start<0) continue;
      if (i-start>=spec.min_band && i-start<=spec.max_band) runs.push({lo:roof+start,hi:roof+i-1,hue});
      start=-1;
    }
  }
  runs.sort((a,b)=>b.hi-a.hi);
  if (!runs.length || mouth-runs[0].hi>spec.base_gap) {
    const empty=spec.empty_ok && base/pixels>=.45 && ![0, .45, .85].some(level=>
      blocked(...map([x,mouth-level*spec.base_gap]),boxes,width,height));
    return empty ? [] : null;
  }
  const stable=[runs[0]];
  for (const run of runs.slice(1)) {
    const separation=stable.at(-1).lo-run.hi-1;
    if (separation>spec.max_gap) break;
    if (separation>=(spec.min_gap ?? 3) || (separation>=0 && run.hue!==stable.at(-1).hue)) stable.push(run);
  }
  return stable.map(run=>COLORS.indexOf(run.hue));
}

export function signature(read, crop, map) {
  const [left,top,right,bottom]=crop;
  const values=new Float32Array(ROWS*COLS*4);
  for (let row=0;row<ROWS;row++) for (let col=0;col<COLS;col++) {
    const dest=(row*COLS+col)*4;
    for (const dy of [.25,.75]) for (const dx of [.25,.75]) {
      const [h,s,v,gray]=read(...map([left+(col+dx)/COLS*(right-left),top+(row+dy)/ROWS*(bottom-top)]));
      const weight=(v>85 ? Math.min(1,Math.max(0,(s-65)/90)) : 0)*63.75;
      values[dest]+=weight*(h<=9 || h>=170);
      values[dest+1]+=weight*(h>=88 && h<=128);
      values[dest+2]+=weight*(h>=18 && h<=43);
      values[dest+3]+=gray/4;
    }
  }
  return values;
}

export function closestCounts(query, examples, goal, strict) {
  if (!examples.length) return null;
  const [left,,right]=goal.crop, span=right-left;
  const anchor=goal.base[0];
  const ranks=examples.map(({counts,values}) => {
    let diff=0, mass=0, weightSum=0, peak=0;
    for (let row=0;row<ROWS;row++) {
      const mid=anchor-.11*span*(1-row/(ROWS-1));
      const center=Math.round((mid-left)/span*COLS);
      const narrow=[0,0,0];
      let narrowCount=0;
      for (let col=0;col<COLS;col++) {
        const offset=(row*COLS+col)*4;
        const weight=.10+.90*Math.exp(-(((left+(col+.5)/COLS*span-mid)/(.30*span))**2));
        weightSum+=weight;
        diff+=Math.abs(query[offset+3]-values[offset+3])*weight;
        for (let ch=0;ch<3;ch++) {
          const difference=query[offset+ch]-values[offset+ch];
          diff+=2*Math.abs(difference)*weight;
          mass+=Math.max(query[offset+ch],values[offset+ch])*weight;
          if (Math.abs(col-center)<=1) narrow[ch]+=difference;
        }
        if (Math.abs(col-center)<=1) narrowCount++;
      }
      if (narrowCount) peak=Math.max(peak,...narrow.map(value=>Math.abs(value)/(255*narrowCount)));
    }
    return {counts, distance:diff/(2*mass+weightSum*255*.18), peak};
  }).sort((a,b)=>a.distance-b.distance);
  const best=ranks[0], competing=ranks.find(candidate=>candidate.counts.join()!==best.counts.join());
  if (!strict && best.distance<.025 && (!competing || competing.distance>.04)) return best;
  if (best.distance>(strict ? .28 : .42) || best.peak>(strict ? .16 : .26) ||
      (competing && competing.distance-best.distance<(strict ? .095 : .07))) return null;
  return best;
}

function adoptCounts(counts, previous) {
  const remaining=[...counts];
  const order=previous.filter(value=>remaining[value]-- > 0);
  remaining.forEach((n,color)=>{ for (let i=0;i<n;i++) order.push(color); });
  return order;
}

function facePixels(read, face, map) {
  const [[ax,ay],[bx,by],half]=face;
  const length=Math.hypot(bx-ax,by-ay);
  const nx=(ay-by)*half/length, ny=(bx-ax)*half/length;
  return Array.from({length:15},(_,row)=>Array.from({length:72},(_,col)=>{
    const along=.075+.85*(col+.5)/72, cross=(row+.5)/7.5-1;
    return read(...map([ax+(bx-ax)*along+nx*cross,ay+(by-ay)*along+ny*cross]));
  }));
}

function visibleColor(rows, minimum) {
  const flat=rows.flat();
  const strengths=COLORS.map(hue=>flat.reduce((sum,pixel)=>sum+color(pixel,hue),0)/flat.length);
  const order=[0,1,2].sort((a,b)=>strengths[b]-strengths[a]);
  return strengths[order[0]]>=minimum && strengths[order[0]]-strengths[order[1]]>=.1 ? COLORS[order[0]] : "unknown";
}

function learnedToggle(rows, model) {
  const vector=[rows,...Array.from({length:3},(_,i)=>rows.slice(i*5,i*5+5))].flatMap(band=>{
    const all=band.flat();
    const ranges=[p=>p[0]>=17&&p[0]<=42,p=>p[0]<=10||p[0]>=170,p=>p[0]>=87&&p[0]<=126,()=>true];
    return ranges.map(matches=>all.filter(p=>p[1]>80&&p[2]>110&&matches(p)).length/all.length);
  });
  const ranked=model.features.map((features,i)=>({owner:model.labels[i],
    distance:Math.hypot(...features.map((value,j)=>value-vector[j]))})).sort((a,b)=>a.distance-b.distance).slice(0,3);
  const first=ranked[0];
  return first?.distance<=.45 && first.owner<3 && ranked.filter(item=>item.owner===first.owner).length>=2 ?
    first.owner : null;
}

// A trained camera stores each goal's look at exact pixel positions. The corners clicked
// for a replay are rarely within a pixel of the ones clicked while labelling, so try small
// shifts and keep the best-aligned match.
// The misalignment is the same all match, so the full search runs until a goal first
// matches; after that only the neighbours of its locked shift are checked.
const SHIFTS=[];
for (let dy=-6;dy<=6;dy+=2) for (let dx=-6;dx<=6;dx+=2) SHIFTS.push([dx,dy]);
function aligned(read, crop, map, match, locks, key) {
  const lock=locks.get(key);
  const tries=lock ? [[0,0],[2,0],[-2,0],[0,2],[0,-2]].map(([x,y])=>[lock[0]+x,lock[1]+y]) : SHIFTS;
  let best=null, shift=null;
  for (const [dx,dy] of tries) {
    const result=match(signature(read,crop,([x,y])=>map([x+dx,y+dy])));
    if (result && (!best || result.distance<best.distance)) { best=result; shift=[dx,dy]; }
  }
  if (shift) locks.set(key,shift);
  return best;
}

export function closestOwner(query, examples) { return rankOwner(query, examples)?.owner ?? null; }

/** Nearest labelled toggle look, or null when the two closest owners are too alike. */
export function rankOwner(query, examples) {
  const ranked=examples.map(({owner,values})=>{
    let diff=0;
    for (let i=0;i<values.length;i++) diff+=Math.abs(query[i]-values[i])*(i%4===3 ? .5 : 1);
    return {owner, distance:diff/values.length/255};
  }).sort((a,b)=>a.distance-b.distance);
  const best=ranked[0], other=ranked.find(item=>item.owner!==best.owner);
  if (!best || best.distance>.16) return null;
  if (other && other.distance-best.distance<.012) return null;
  return best;
}

export const FIELD_CORNERS=[[0,0],[144,0],[144,144],[0,144]];

export function referenceReader(model, project, width, height, goals, baseAnchors) {
  const toImage=point=>project(point).map((v,i)=>v*(i ? height : width));
  const currentCorners=FIELD_CORNERS.map(project);
  const ranked=model.cameras.map(camera=>({camera, distance:Math.sqrt(camera.corners.reduce((sum,corner,i)=>
    sum+corner.reduce((value,x,j)=>value+(x-currentCorners[i][j])**2,0),0)/8)})).sort((a,b)=>a.distance-b.distance);
  const {camera,distance}=ranked[0];
  const calibrated=distance<=.034;
  const scale=width/camera.size[0];
  const offset=currentCorners.reduce((total, point,i)=>total.map((value,j)=>
    value+(point[j]-camera.corners[i][j])*(j ? height : width)/4),[0,0]);
  const cameraPoint=([x,y])=>[x*scale+offset[0],y*(height/camera.size[1])+offset[1]];
  let read, boxesNow=[];
  const locks=new Map();

  return {
    label:calibrated ? camera.name : "Three-event scoring references",
    calibrated,
    use(canvas, boxes=[]) { read=pixelReader(canvas); boxesNow=boxes; },
    stack(id, index, previous, boxes, geometric) {
      const goal=camera.goals.find(g=>g.id===id);
      if (calibrated && camera.unreadableGoals.includes(id)) return null;
      const anchor=baseAnchors[index], point=calibrated ? cameraPoint(goal.base) :
        anchor ? [anchor.x,anchor.y+anchor.unit*2] : toImage(goals[index].point);
      if (calibrated) {
        const examples=camera.references[id];
        const nearest=!examples.length || blocked(...point,boxes,width,height) ? null :
          camera.kind==="scoring-camera" ? aligned(read,goal.crop,cameraPoint,sig=>closestCounts(sig,examples,goal,false),locks,id) :
          closestCounts(signature(read,goal.crop,cameraPoint),examples,goal,false);
        if (nearest?.distance<=.13) return adoptCounts(nearest.counts,previous);
        const column=camera.columns[id];
        const measured=column && bands(read,column,cameraPoint,boxes,width,height);
        if (measured && measured.length<previous.length) {
          const reach=Math.min(column.mouth-column.roof,column.base_gap+previous.length*column.max_gap*.7);
          const mask=[.25,.50,.75,1].some(fraction=>blocked(
            ...cameraPoint([column.x+column.slope*reach*fraction,column.mouth-reach*fraction]),boxes,width,height));
          if (mask) return null;
        }
        return measured || (nearest ? adoptCounts(nearest.counts,previous) : null);
      }
      if (blocked(...point,boxes,width,height)) return null;
      let measured;
      if (anchor) {
        const {x,y,unit,base,slope}=anchor;
        const mouth=Math.round(y-unit*(base<2 ? 1.05 : .5));
        const spec={x,mouth,slope,roof:Math.max(0,Math.round(mouth-unit*27)),
          base_patch:[x-unit,y,x+unit,y+unit*2.4],base_color:COLORS[base] || "dark",
          colors:COLORS,width:Math.max(2,Math.round(.95*unit)),min_band:Math.max(2,Math.round(unit*.65)),
          max_band:Math.round(unit*5.2),base_gap:unit*7,max_gap:unit*5.1,min_gap:Math.max(1,Math.round(unit*.40))};
        measured=bands(read,spec,p=>p,boxes,width,height);
        if (measured?.length>1 && measured.join()===geometric?.join()) return measured;
      }
      for (const {camera:source} of ranked) {
        const template=source.goals.find(g=>g.id===id);
        if (!template || !source.references[id]?.length) continue;
        const map=([x,y])=>{
          const ratio=width/source.size[0];
          return [point[0]+(x-template.base[0])*ratio, point[1]+(y-template.base[1])*ratio];
        };
        const sample=signature(read,template.crop,map);
        const nearest=closestCounts(sample,source.references[id],template,true);
        if (!nearest) continue;
        if (nearest.counts.some(Boolean)!==Boolean(measured?.length || geometric?.length)) continue;
        const ordered=measured || geometric;
        if (ordered && COLORS.every((_,color)=>ordered.filter(value=>value===color).length===nearest.counts[color])) {
          return ordered;
        }
        return adoptCounts(nearest.counts,previous);
      }
      return null;
    },
    toggle(wall, samples) {
      if (calibrated && camera.toggleReferences) {
        const crop=camera.toggleCrops?.[wall], examples=camera.toggleReferences[wall];
        if (!crop || !examples?.length) return null;
        const center=cameraPoint([(crop[0]+crop[2])/2,(crop[1]+crop[3])/2]);
        if (blocked(...center,boxesNow,width,height)) return null;
        return aligned(read,crop,cameraPoint,sig=>rankOwner(sig,examples),locks,wall)?.owner ?? null;
      }
      if (!calibrated) {
        if (!samples) return null;
        const [a,b]=[samples[0],samples.at(-1)];
        const rows=facePixels(read,[a,b,2],point=>point);
        return learnedToggle(rows, model.toggles);
      }
      const visible=camera.visibleFaces[wall];
      if (visible) return OWNERS[visible.colors[visibleColor(facePixels(read,visible.crop,cameraPoint),.58)]] ?? null;
      const outward=camera.toggleFaces[wall], inside=camera.insideFaces[wall];
      if (!outward) return null;
      const rows=facePixels(read,outward,cameraPoint);
      if (!inside) return learnedToggle(rows, model.toggles);
      const out=visibleColor(rows,.62);
      const inner=visibleColor(facePixels(read,inside,cameraPoint),.23);
      const byPair={"red:blue":1,"blue:yellow":2,"yellow:red":0};
      if (byPair[inner+":"+out]!=null) return byPair[inner+":"+out];
      const edge=camera.yellowEdges[wall];
      if (edge && out==="red") {
        const yellow=facePixels(read,edge,cameraPoint).map(row=>row.filter(p=>color(p,"yellow")).length/row.length);
        if (Math.max(...yellow)>=.36 && yellow.reduce((sum,x)=>sum+x,0)/yellow.length>=.14) return 0;
      }
      return null;
    },
  };
}
