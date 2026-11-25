import {referenceReader} from "./scoring-model.js?v=load7";

export const wallPoints = {far:[72,0], left:[0,72], right:[144,72], near:[72,144]};
const walls = Object.keys(wallPoints);
const colorNames = ["Red", "Blue", "Yellow"];
const coords = {
  "far-neutral":[-600,1200], "far-blue":[600,1200], "left-neutral":[-1200,600],
  "left-red":[-1200,-600], midfield:[0,0], "right-blue":[1200,600],
  "right-neutral":[1200,-600], "near-red":[-600,-1200], "near-neutral":[600,-1200],
};
export const goals = Object.entries(coords).map(([id, [x,y]]) => ({
  id, name:id.replace("-", " · "), point:[72 + x / 25.4, 72 - y / 25.4],
}));
const opening = goal => goal.id === "midfield" || goal.id.endsWith("neutral") ? [2] : [];
const gap = (a,b) => Math.hypot(a[0]-b[0],a[1]-b[1]);

function pixels(canvas, luminance = false) {
  const {width, height} = canvas;
  const image = canvas.getContext("2d").getImageData(0,0,width,height).data;
  return (x,y) => {
    x = Math.round(x); y = Math.round(y);
    if (x < 0 || x >= width || y < 0 || y >= height) return -1;
    const i = (y*width+x)*4, r=image[i], g=image[i+1], b=image[i+2];
    if (luminance) return .21*r + .72*g + .07*b;
    if (Math.max(r,g,b) < 117 && Math.max(r,g,b)-Math.min(r,g,b) < 43) return 3;
    if (r > 1.31*g && r > 1.19*b && r > 119) return 0;
    if (b > 1.28*r && g > 1.12*r && b >= g*.95 && b > 111) return 1;
    if (r > 126 && g > 116 && b < Math.min(r,g)*.65 && r > g*.80 && g > r*.65) return 2;
    return -1;
  };
}

function findMark(read, guess, color, radius, eligible) {
  let best, bestScore = 0;
  for (let y=guess[1]-radius; y<=guess[1]+radius; y+=2) {
    for (let x=guess[0]-radius; x<=guess[0]+radius; x+=2) {
      if (read(x,y) !== color || !eligible(x,y)) continue;
      let agree = 0;
      for (const dy of [-4,0,4]) for (const dx of [-4,0,4]) agree += +(read(x+dx,y+dy) === color);
      const score = agree - 5*gap([x,y],guess)/radius;
      if (agree >= 5 && score > bestScore) { bestScore=score; best=[x,y]; }
    }
  }
  return best;
}

function countStack(read, anchor, boxes, width, height, priorHeight) {
  if (!anchor) return null;
  const {x,y,unit,base,slope} = anchor;
  let evidence = 0;
  for (const d of [-.8,0,.8]) {
    for (const level of [0,.8,1.6,2.4]) evidence += +(read(x+d*unit,y+unit*level) === base);
  }
  if (evidence < 4) return null;
  const lanes = [[0,slope],[-.8,slope-.028],[.8,slope+.028]].map(([shift,lean]) =>
    readBands(read,{...anchor,x:x+shift*unit},lean,boxes,width,height,priorHeight));
  if (lanes[0] === null) return null;
  // Take the middle count so a single ray intersecting a loose pin cannot extend the stack.
  const supported = lanes.filter(stack=>stack!==null).sort((a,b)=>a.length-b.length);
  return supported[Math.floor((supported.length-1)/2)];
}

function readBands(read, {x,y,unit,base}, slope, boxes, width, height, priorHeight) {
  const stack = [];
  let previous = -1, length=0, lastBand=0, lastEnd=-5;
  for (let i=0; i<=65; i++) {
    const vertical = i*.55*unit + (base < 2 ? unit*1.55 : 0);
    const centerX = x + slope*vertical, centerY = y - vertical;
    if (centerY < 0) break;
    const blocked = boxes.some(box => centerX/width >= box.x && centerX/width <= box.x + box.w &&
      centerY/height >= box.y && centerY/height <= box.y + box.h);
    if (blocked) {
      if (i <= Math.max(6, priorHeight * 8) && stack.length < priorHeight) return null;
      break;
    }
    const sample = [-.9,-.45,0,.45,.9].map(d => read(centerX+d*unit,centerY));
    const value = [0,1,2].find(color => sample.filter(c=>c===color).length >= 3) ?? -1;
    if (value !== previous) {
      if (previous >= 0 && length >= 2 && length <= 16 &&
          !(base < 2 && lastBand === 0 && previous === base && i < 4)) {
        if (previous!==stack.at(-1) || i-length-lastEnd>=2) stack.push(previous);
        lastBand=i; lastEnd=i;
      }
      length=0; previous=value;
    }
    length++;
    const gapLimit = stack.length ? 14 : base === 3 ? 17 : 11;
    if (value === -1 && i-lastBand > gapLimit) break;
  }
  return stack;
}

export function score(counts, ownership) {
  const totals = [0,0];
  goals.forEach(({id}, i) => {
    const owner = ownership[id.split("-")[0]];
    counts[i]?.forEach(color => {
      if (color !== 2) totals[color] += 5;
      else if (owner) totals[owner - 1] += 10;
    });
  });
  return totals;
}

const titled = value => value[0].toUpperCase() + value.slice(1);

function fixedView(frame, image) {
  const read = pixels(frame, true);
  const slices = [
    [x => [x, 1], x => [x, -3]], [x => [x, 143], x => [x,147]],
    [y => [1,y], y => [-3,y]], [y => [143,y], y => [147,y]],
  ];
  const patches = slices.map(edges => edges.flatMap(edge => Array.from({length:21}, (_,i)=>image(edge(12+i*6))))
    .map(point=>({point, gray:read(...point)})).filter(item=>item.gray>=0));
  return canvas => {
    const current = pixels(canvas, true);
    const changed = patches.filter(patch => patch.length >= 20 &&
      patch.filter(({point,gray})=>Math.abs(current(...point)-gray)>42).length/patch.length > .49).length;
    return changed < 3;
  };
}

// Keep the order of pins already on a goal and append whatever a checked count adds.
function ordered(counts, previous) {
  const remaining=[...counts];
  const order=previous.filter(color=>remaining[color]-- > 0);
  remaining.forEach((n,color)=>{ for (let i=0;i<n;i++) order.push(color); });
  return order;
}

// anchors: [{frame, goals:{id:[r,b,y]|null}, toggles:{wall:0|1|2|null}}] from "Check the
// scoring" answers for this video. At those moments the replay takes the person's answer,
// and holds it against the reader for a few seconds, so a toggle the camera cannot read
// (for example the far face of the near toggle) still changes when it really did.
export function buildScoring(frame, project, teams, fps, model, anchors=[]) {
  const {width,height} = frame;
  const image = point => project(point).map((value, i) => value * (i ? height : width));
  const middle = image([72,72])[0];
  const initial = pixels(frame);
  const cameraMatches = fixedView(frame, image);
  const bases = goals.map(goal => {
    const [gx,gy] = goal.point, foot = image(goal.point);
    const unit = gap(foot,image([gx+4,gy]))/4;
    const base = goal.id.endsWith("-red") ? 0 : goal.id.endsWith("-blue") ? 1 : 3;
    const estimate = [foot[0],foot[1]-unit*(base === 3 ? 3 : 0)];
    const nearColumn = x => Math.abs(x-foot[0]) <= Math.max(9,unit*4.5);
    const aboveBase = (x,y) => [-.65,0,.65].flatMap(dx =>
      [2.2,3.15,4.1].map(dy => initial(x+dx*unit,y+dy*unit))).filter(color=>color===3).length >= 4;
    const mark = findMark(initial, estimate, base === 3 ? 2 : base, Math.max(16,Math.min(43,unit*11)),
      (x,y)=>nearColumn(x) && (base!==3 || aboveBase(x,y)));
    if (!mark) return null;
    return {x:mark[0], y:mark[1]+(base === 3 ? unit*2.35 : 0), unit, base,
      slope:(mark[0]-middle)/(width*3.6)};
  });
  const decoder = referenceReader(model,project,width,height,goals,bases);
  const toggles = walls.map(wall => {
    const [wx,wy] = wallPoints[wall], [x,y]=image([wx,wy]);
    const along = wall === "near" || wall === "far";
    const a=image([wx-(along?10:0),wy-(along?0:10)]), b=image([wx+(along?10:0),wy+(along?0:10)]);
    const dx=(b[0]-a[0])/2,dy=(b[1]-a[1])/2;
    const min=Math.min(60,Math.hypot(dx,dy)*1.2);
    let best=null, bestScore=0;
    for (let v=-Math.min(75,min*1.5);v<=min*.25;v+=2) for (let u=-min*.35;u<=min*.35;u+=3) {
      const positions=Array.from({length:17},(_,i)=>[x+u+dx*(i/8-1),y+v+dy*(i/8-1)]);
      const votes=positions.filter(([x0,y0])=>initial(x0,y0)===2).length;
      if (votes>=9 && votes>bestScore) { best=positions; bestScore=votes; }
    }
    return best;
  });
  const stacks=goals.map(opening);
  const ownership=Object.fromEntries(walls.map(wall=>[wall,0]));
  const seen=goals.map(()=>null), wallSeen=walls.map(()=>null);
  const pending=new Map(), plays=[], states=[];
  const calls=goals.map(()=>0);
  let checks=0, usableChecks=0;

  function stable(id, reading, minimum=3) {
    if (reading === null) { pending.delete(id); return false; }
    const key=JSON.stringify(reading), current=pending.get(id);
    const count=current?.key===key ? current.count+1 : 1;
    pending.set(id,{key,count});
    return count >= minimum;
  }

  function change(frame, points, point, positions, details) {
    const next=score(stacks,ownership).map((value,i)=>value-points[i]);
    const candidates=positions.map((position,i)=>({team:teams[i].team,gap:position[2]===1?gap(point,position):Infinity}))
      .sort((a,b)=>a.gap-b.gap);
    const actor=candidates[0].gap<18 && candidates[1].gap-candidates[0].gap>8 ? candidates[0].team : null;
    plays.push({frame, actionFrame:frame, window:[Math.max(0,frame-fps),frame],
      actor, actorEvidence:actor ? "track" : null, points:next, ...details});
  }

  const checked=[...anchors].sort((a,b)=>a.frame-b.frame), hold=new Map();
  let nextCheck=0;
  const held=(id,frame)=>(hold.get(id) ?? -1)>frame;
  function applyChecks(frame, positions) {
    while (nextCheck<checked.length && checked[nextCheck].frame<=frame) {
      const answer=checked[nextCheck++];
      goals.forEach((goal,i)=>{
        const counts=answer.goals?.[goal.id];
        if (!Array.isArray(counts)) return;
        hold.set(goal.id,frame+fps*5); pending.delete(goal.id); seen[i]=frame;
        const previous=stacks[i], current=ordered(counts,previous);
        if (current.join()===previous.join()) return;
        const points=score(stacks,ownership);
        const delta=colorNames.map((_,c)=>current.filter(color=>color===c).length-previous.filter(color=>color===c).length);
        stacks[i]=current;
        change(frame,points,goal.point,positions,{title:`Goal ${i+1} ${delta.every(value=>value<=0)?"descore":"stack change"} (your check)`,
          kind:"stack", goals:[goal.id], wall:null, pinDelta:delta, checked:true,
          detail:delta.flatMap((value,c)=>value ? [`${value>0?"+":""}${value} ${colorNames[c].toLowerCase()}`] : []).join(" · ")});
      });
      walls.forEach((wall,i)=>{
        const owner=answer.toggles?.[wall];
        if (!Number.isInteger(owner)) return;
        hold.set(wall,frame+fps*5); pending.delete(wall); wallSeen[i]=frame;
        if (owner===ownership[wall]) return;
        const previous=ownership[wall], points=score(stacks,ownership);
        ownership[wall]=owner;
        change(frame,points,wallPoints[wall],positions,{title:`${titled(wall)} toggle changes (your check)`,kind:"toggle",
          wall,goals:goals.filter(goal=>goal.id.startsWith(wall+"-")).map(goal=>goal.id),pinDelta:null,checked:true,
          detail:`${["Neutral","Red","Blue"][previous]} to ${["Neutral","Red","Blue"][owner]}`});
      });
    }
  }

  return {
    cameraMatches,
    read(canvas, frame, boxes, positions, cameraClear=true) {
      if (frame % fps === 0) checks++;
      if (cameraClear && frame % fps === 0) usableChecks++;
      if (!cameraClear) pending.clear();
      applyChecks(frame, positions);
      if (frame && cameraClear) {
        const read=pixels(canvas);
        decoder.use(canvas,boxes);
        bases.forEach((base,i)=>{
          if (held(goals[i].id,frame)) return;
          const previous=stacks[i];
          const geometric=decoder.calibrated ? null : countStack(read,base,boxes,width,height,previous.length);
          const current=decoder.stack(goals[i].id,i,previous,boxes,geometric);
          const dropping=current !== null && current.length<previous.length;
          if (!stable(goals[i].id,current,dropping?5:3)) return;
          if (current !== null) {
            if (frame % fps===0) calls[i]++;
            seen[i]=frame;
          }
          if (current.join()===previous.join()) return;
          const points=score(stacks,ownership);
          const delta=colorNames.map((_,c)=>current.filter(color=>color===c).length-previous.filter(color=>color===c).length);
          stacks[i]=current;
          if (delta.some(Boolean)) change(frame,points,goals[i].point,positions,{
            title:`Goal ${i+1} ${delta.every(value=>value<=0)?"descore":"stack change"}`,
            kind:"stack", goals:[goals[i].id], wall:null, pinDelta:delta,
            detail:delta.flatMap((value,c)=>value ? [`${value>0?"+":""}${value} ${colorNames[c].toLowerCase()}`] : []).join(" · "),
          });
        });
        toggles.forEach((samples,i)=>{
          if (held(walls[i],frame)) return;
          const wall=walls[i], next=decoder.toggle(wall,samples);
          if (!stable(wall,next)) return;
          wallSeen[i]=frame;
          if (next===ownership[wall]) return;
          const previous=ownership[wall], points=score(stacks,ownership);
          ownership[wall]=next;
          change(frame,points,wallPoints[wall],positions,{title:`${titled(wall)} toggle changes`,kind:"toggle",
            wall,goals:goals.filter(goal=>goal.id.startsWith(wall+"-")).map(goal=>goal.id),pinDelta:null,
            detail:`${["Neutral","Red","Blue"][previous]} to ${["Neutral","Red","Blue"][next]}`});
        });
      }
      states.push([frame,score(stacks,ownership),goals.map((g,i)=>{
        if (seen[i]===null && frame>0 && stacks[i].length===0) return null;
        const stack=stacks[i];
        return [...colorNames.map((_,c)=>stack.filter(color=>color===c).length),
          +(frame>0 && (seen[i]===null || frame-seen[i]>fps*2)),[...stack],+(seen[i]===null)];
      }),walls.map((wall,i)=>[ownership[wall],+(frame>0 && (wallSeen[i]===null || frame-wallSeen[i]>fps*2))]),
      [seen.filter(at=>at!==null && frame-at<=fps*2).length,
        seen.filter(at=>at!==null && frame-at>fps*2).length,wallSeen.filter(at=>at!==null).length]]);
    },
    finish(meta, tracks, fps, last, backend) {
      const autonomousEnd=Math.min(last,15*fps), driverStart=Math.round((meta.driver-meta.start)*fps);
      const everyHalfSecond=fps/2;
      const performance=Object.fromEntries(teams.map(entry=>{
        const mine=plays.filter(play=>play.actor===entry.team);
        const placements=mine.filter(play=>play.kind==="stack" && play.pinDelta.some(value=>value>0));
        const driver=placements.filter(play=>play.frame>=driverStart);
        const gaps=driver.slice(1).map((play,k)=>(play.frame-driver[k].frame)/fps).filter(value=>value>=1.5).sort((a,b)=>a-b);
        const auto=mine.filter(play=>play.frame<=autonomousEnd);
        const path=tracks[entry.team];
        const speeds=[];
        let autoDistance=0, autoCount=0, driverCount=0;
        for (let index=everyHalfSecond;index<path.length;index+=everyHalfSecond) {
          const a=path[index-everyHalfSecond],b=path[index];
          if (index<=autonomousEnd && b?.[2]===1) autoCount++;
          if (index>=driverStart && b?.[2]===1) driverCount++;
          if (!a?.[2] || !b?.[2]) continue;
          const feet=gap(a,b)/12;
          if (index<=autonomousEnd && feet<4) autoDistance+=feet;
          else if(index>=driverStart && feet>.08 && feet<4) speeds.push(feet*2);
        }
        speeds.sort((a,b)=>a-b);
        const side=+(entry.alliance==="blue");
        return [entry.team,{
          rating:null, confidence:"low", autoPoints:auto.length ? auto.reduce((sum,play)=>sum+play.points[side],0):null,
          autoCoverage:Math.min(100,Math.round(autoCount/(autonomousEnd/everyHalfSecond || 1)*100)), autoDistanceFt:+autoDistance.toFixed(1),
          stacks:placements.length, possibleStacks:0, cycleSeconds:gaps.length?+gaps[Math.floor(gaps.length/2)].toFixed(1):null,
          cycleSamples:gaps.length, cycleTentative:true, loaderTripSeconds:null, loaderTrips:0, goalApproachSeconds:null,
          goalApproachGaps:0, speed:speeds.length?+speeds[Math.floor(speeds.length/2)].toFixed(1):null,
          fastSpeed:speeds.length?+speeds[Math.floor(speeds.length*.90)].toFixed(1):null,speedSamples:speeds.length,
          driveCoverage:Math.min(100,Math.round(driverCount/((last-driverStart)/everyHalfSecond || 1)*100)), retakes:mine.filter(play=>play.kind==="toggle" &&
            play.detail===`${side?"Red":"Blue"} to ${side?"Blue":"Red"}`).length, contestedHold:null,
        }];
      }));
      return {
        event:"browser-import",title:meta.event,round:meta.round,fps,duration:(last+1)/fps,autonomousEnd,driverStart,
        driverEnd:last,finalFrame:last,finalScore:meta.final,videoOffset:meta.start,teams,goals,walls,tracks,states,plays,
        scoreBreakdown:{autonomousScore:states.filter(state=>state[0]<=autonomousEnd).at(-1)[1]},scoringReviewed:false,
        scoringReference:decoder.label, scoringVersion:2,
        goalAudit:{goals:9,clock_checks:checks,usable_clock_checks:usableChecks,
          goal_reads:Object.fromEntries(goals.map((goal,i)=>[goal.id,calls[i]])),gpu:backend},
        performance,
      };
    },
  };
}
