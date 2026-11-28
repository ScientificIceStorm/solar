// Vision UI landing page: a flowing colour field behind the page, scroll-linked hero and brain
// tilt, and a V5 brain screen that plays the Near side 2 route as the page scrolls.
(() => {
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const $ = id => document.getElementById(id);

  // ---- Fluid background: soft colour blobs drifting on slow loops, blurred by CSS ----------
  const fluid = $("fluid"), f = fluid.getContext("2d");
  const blobs = [
    {c: "#1d4ed8", r: .55, a: 0, s: .00011, ox: .25, oy: .3},
    {c: "#22d3ee", r: .42, a: 2, s: .00015, ox: .75, oy: .25},
    {c: "#7c3aed", r: .5, a: 4, s: .00009, ox: .6, oy: .75},
    {c: "#0ea5e9", r: .36, a: 1, s: .00019, ox: .2, oy: .8},
    {c: "#312e81", r: .6, a: 3, s: .00007, ox: .5, oy: .5},
  ];
  let fw = 0, fh = 0, scrolled = 0;
  function fitFluid() {
    fw = fluid.width = Math.ceil(innerWidth / 4);
    fh = fluid.height = Math.ceil(innerHeight / 4);
  }
  function drawFluid(time) {
    f.fillStyle = "#060b1c";
    f.fillRect(0, 0, fw, fh);
    f.globalCompositeOperation = "lighter";
    const drift = scrolled * .00035;
    for (const b of blobs) {
      const t = time * b.s + b.a + drift;
      const x = (b.ox + .22 * Math.sin(t * 1.3) + .1 * Math.cos(t * 2.1)) * fw;
      const y = (b.oy + .2 * Math.cos(t * 1.1) + .08 * Math.sin(t * 2.7)) * fh;
      const r = b.r * Math.max(fw, fh) * (.85 + .15 * Math.sin(t * 3));
      const grad = f.createRadialGradient(x, y, 0, x, y, r);
      grad.addColorStop(0, b.c + "cc");
      grad.addColorStop(1, b.c + "00");
      f.fillStyle = grad;
      f.fillRect(0, 0, fw, fh);
    }
    f.globalCompositeOperation = "source-over";
  }
  fitFluid();
  addEventListener("resize", fitFluid);

  // ---- Reveal on scroll ----------------------------------------------------------------------
  const seen = new IntersectionObserver(entries => {
    for (const entry of entries) if (entry.isIntersecting) { entry.target.classList.add("in"); seen.unobserve(entry.target); }
  }, {threshold: .18, rootMargin: "0px 0px -6% 0px"});
  document.querySelectorAll(".reveal").forEach(el => seen.observe(el));

  // ---- The brain screen (960 x 480, laid out like the real one) -----------------------------
  const NS = "http://www.w3.org/2000/svg";
  const svg = $("brain");
  const el = (name, attrs = {}, parent = svg, text) => {
    const node = document.createElementNS(NS, name);
    for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, v);
    if (text != null) node.textContent = text;
    parent.append(node);
    return node;
  };
  const FONT = "Manrope, system-ui, sans-serif";
  el("rect", {width: 960, height: 480, fill: "#070d22"});

  // Field map: the Override field drawn in the brain's style.
  const map = el("g");
  el("rect", {x: 15, y: 15, width: 450, height: 450, fill: "#26282d", stroke: "#8c919c", "stroke-width": 6}, map);
  for (let i = 1; i < 6; i++) {
    el("line", {x1: 15 + i * 75, y1: 18, x2: 15 + i * 75, y2: 462, stroke: "#1f2125", "stroke-width": 2}, map);
    el("line", {x1: 18, y1: 15 + i * 75, x2: 462, y2: 15 + i * 75, stroke: "#1f2125", "stroke-width": 2}, map);
  }
  const line = (x1, y1, x2, y2, w = 2.2, c = "#e9edf5") => el("line", {x1, y1, x2, y2, stroke: c, "stroke-width": w, "stroke-linecap": "round"}, map);
  for (const d of [-4, 4]) { line(58 + d, 55 - d, 170 + d, 167 - d); line(310 + d, 312 - d, 425 + d, 425 - d); }
  line(445, 60, 310, 170); line(170, 310, 58, 420);
  el("polygon", {points: "240,170 310,240 240,310 170,240", fill: "none", stroke: "#e9edf5", "stroke-width": 2.2}, map);
  line(55, 18, 55, 95, 2, "#c43a3a"); line(18, 95, 55, 95, 2, "#c43a3a"); line(55, 462, 55, 385, 2, "#c43a3a"); line(18, 385, 55, 385, 2, "#c43a3a");
  line(425, 18, 425, 95, 2, "#3a6fc4"); line(462, 95, 425, 95, 2, "#3a6fc4"); line(425, 462, 425, 385, 2, "#3a6fc4"); line(462, 385, 425, 385, 2, "#3a6fc4");
  for (const [x, y] of [[95, 25], [165, 25], [315, 25], [385, 95], [95, 165], [315, 165], [240, 240], [25, 165], [165, 455], [315, 455], [455, 315], [25, 315], [385, 315], [165, 315], [95, 455], [385, 455]])
    el("circle", {cx: x, cy: y, r: 5, fill: "#c9b440"}, map);
  for (const [x, y] of [[95, 95], [165, 170], [315, 315], [385, 385]]) {
    const star = el("g", {transform: `translate(${x} ${y})`}, map);
    [["#d23b3b", 0], ["#2f7fe0", 90], ["#d23b3b", 180], ["#2f7fe0", 270], ["#e3c13c", 45], ["#e3c13c", 225]].forEach(([c, a]) =>
      el("line", {x1: 0, y1: 0, x2: 16 * Math.cos(a * Math.PI / 180), y2: 16 * Math.sin(a * Math.PI / 180), stroke: c, "stroke-width": 3.4, "stroke-linecap": "round"}, star));
    el("circle", {r: 4, fill: "#e3c13c"}, star);
  }
  for (const [x, y, c] of [[313, 95, "#2f7fe0"], [385, 167, "#2f7fe0"], [168, 385, "#d23b3b"]]) {
    el("rect", {x: x - 7, y: y - 7, width: 14, height: 14, rx: 3, fill: "none", stroke: c, "stroke-width": 3}, map);
    el("circle", {cx: x, cy: y, r: 2.5, fill: c}, map);
  }
  for (const [x, y, w, h] of [[200, 12, 80, 6], [200, 462, 80, 6], [12, 200, 6, 80], [462, 200, 6, 80]])
    el("rect", {x, y, width: w, height: h, rx: 2, fill: "#d6b43a"}, map);

  // The route: Near side 2, with waypoints where the real screen numbers them.
  const P = {S: [27, 240], 1: [93, 240], 2: [93, 310], 3: [93, 240], 4: [167, 308], 5: [93, 323], 6: [167, 308], 7: [93, 385], 8: [128, 352]};
  const STEPS = [
    {kind: "drive", to: 1, speed: 80}, {kind: "turn", face: 2, speed: 40, label: "TURN TO 2"},
    {kind: "reverse", to: 2, speed: 60}, {kind: "drive", to: 3, speed: 80}, {kind: "turn", face: 4, speed: 40, label: "TURN TO 4"},
    {kind: "drive", to: 4, speed: 60}, {kind: "reverse", to: 5, speed: 60}, {kind: "drive", to: 6, speed: 70},
    {kind: "turn", face: 7, speed: 40, label: "TURN TO 7"}, {kind: "drive", to: 7, speed: 80}, {kind: "turn", face: 8, speed: 40, label: "TURN TO 8"},
    {kind: "drive", to: 8, speed: 60}, {kind: "turn", heading: 0, speed: 40, label: "TURN TO 0°"},
  ];
  const COLOR = {drive: "#3cc9f0", reverse: "#f6a13a", turn: "#9b8cff"};
  // Walk the route once to know where each step starts and ends.
  let pos = P.S, heading = 90;
  const bearing = (a, b) => Math.atan2(b[0] - a[0], -(b[1] - a[1])) * 180 / Math.PI;
  for (const step of STEPS) {
    step.from = pos; step.h0 = heading;
    if (step.kind === "turn") {
      step.h1 = step.heading ?? bearing(pos, P[step.face]);
      step.end = pos;
    } else {
      const target = P[step.to];
      const travel = bearing(pos, target);
      step.h1 = step.kind === "reverse" ? travel + 180 : travel;
      step.end = target;
      step.label = `${step.kind === "reverse" ? "REVERSE" : "DRIVE"} TO ${step.to}`;
    }
    pos = step.end; heading = step.h1;
  }
  const paths = el("g");
  const segments = STEPS.filter(s => s.kind !== "turn").map(step => {
    const back = el("line", {x1: step.from[0], y1: step.from[1], x2: step.end[0], y2: step.end[1], stroke: COLOR[step.kind], "stroke-opacity": .22, "stroke-width": 5, "stroke-linecap": "round"}, paths);
    const live = el("line", {x1: step.from[0], y1: step.from[1], x2: step.from[0], y2: step.from[1], stroke: COLOR[step.kind], "stroke-width": 5, "stroke-linecap": "round"}, paths);
    return {step, back, live};
  });
  const labels = el("g");
  const tag = (text, x, y, active) => {
    const g = el("g", {transform: `translate(${x} ${y})`}, labels);
    const w = 14 + text.length * 11;
    el("rect", {x: -w / 2, y: -12, width: w, height: 24, rx: 5, fill: active ? "#3cc9f0" : "#0e1530", stroke: active ? "none" : "#8fa0c8", "stroke-width": 1.5}, g);
    el("text", {y: 6, "text-anchor": "middle", fill: active ? "#04122a" : "#e8eefc", "font-size": 16, "font-family": FONT, "font-weight": 600}, g, text);
    return g;
  };
  for (const p of new Set(Object.values(P).map(String))) { const [x, y] = p.split(",").map(Number); el("circle", {cx: x, cy: y, r: 4.5, fill: "#fff"}, paths); }
  tag("S", 48, 215); const tag13 = tag("1,3", 93, 215); tag("2", 65, 287); const tag46 = tag("4,6", 203, 283); tag("5", 66, 348); tag("8", 152, 352); tag("7", 117, 386);
  const robot = el("g");
  el("rect", {x: -22, y: -22, width: 44, height: 44, rx: 4, fill: "#141c3a", stroke: "#fff", "stroke-width": 3.5, transform: "rotate(45)"}, robot);
  el("polygon", {points: "0,-14 11,9 -11,9", fill: "#32d17c"}, robot);

  // Right-hand panel and rail, as on the brain.
  const text = (t, x, y, size, fill, weight = 600, anchor = "start") => el("text", {x, y, "font-size": size, fill, "font-weight": weight, "font-family": FONT, "text-anchor": anchor}, svg, t);
  text("AUTONOMOUS", 481, 47, 30, "#fff");
  text("READY", 856, 47, 23, "#4ade80", 700, "end");
  el("rect", {x: 482, y: 67, width: 372, height: 58, rx: 10, fill: "#16224c", stroke: "#3cc9f0", "stroke-width": 3});
  text("NEAR SIDE 2", 668, 106, 26, "#fff", 600, "middle");
  el("rect", {x: 482, y: 138, width: 372, height: 58, rx: 10, fill: "#0e1633", stroke: "#26345e", "stroke-width": 2});
  text("FAR SIDE 2", 668, 177, 26, "#e6ecfa", 600, "middle");
  el("rect", {x: 482, y: 217, width: 372, height: 145, rx: 10, fill: "#0f1735"});
  const stepCount = text("STEP 1 / 13", 500, 248, 17, "#9fb0d0", 600);
  const arrow = el("path", {d: "M-11 6 L0 -6 L11 6", fill: "none", stroke: "#3cc9f0", "stroke-width": 4, "stroke-linecap": "round", "stroke-linejoin": "round"});
  const stepLabel = text("DRIVE TO 1", 553, 298, 33, "#3cc9f0", 600);
  const odo = text("x -47.1  y 0.0  speed 80", 500, 336, 21, "#c8d2e8", 500);
  el("rect", {x: 500, y: 348, width: 336, height: 6, rx: 3, fill: "#26345e"});
  const bar = el("rect", {x: 500, y: 348, width: 0, height: 6, rx: 3, fill: "#3cc9f0"});
  for (const [x, icon] of [[482, "prev"], [610, "pause"], [738, "next"]]) {
    el("rect", {x, y: 373, width: 116, height: 58, rx: 9, fill: "#0e1633", stroke: "#26345e", "stroke-width": 2});
    const cx = x + 58, cy = 402;
    if (icon === "pause") { el("rect", {x: cx - 11, y: cy - 12, width: 7, height: 24, rx: 1.5, fill: "#fff"}); el("rect", {x: cx + 4, y: cy - 12, width: 7, height: 24, rx: 1.5, fill: "#fff"}); }
    else {
      const flip = icon === "prev" ? -1 : 1;
      el("polygon", {points: `${cx - 8 * flip},${cy - 12} ${cx + 6 * flip},${cy} ${cx - 8 * flip},${cy + 12}`, fill: "#fff"});
      el("rect", {x: flip > 0 ? cx + 7 : cx - 11, y: cy - 12, width: 4, height: 24, fill: "#fff"});
    }
  }
  [["#3cc9f0", "Forward", 484], ["#f6a13a", "Reverse", 620], ["#9b8cff", "Turn", 757]].forEach(([c, t, x]) => {
    el("rect", {x, y: 446, width: 14, height: 14, rx: 2, fill: c});
    text(t, x + 23, 459, 19, "#c8d2e8", 500);
  });
  el("rect", {x: 873, y: 0, width: 87, height: 480, fill: "#141b36"});
  el("rect", {x: 873, y: 28, width: 5, height: 104, rx: 2, fill: "#3cc9f0"});
  el("polygon", {points: "898,44 932,62 898,80", fill: "#3cc9f0"});
  text("AUTO", 916, 118, 19, "#fff", 600, "middle");
  el("path", {d: "M921 202 L905 228 L917 228 L911 250 L929 220 L917 220 L925 202 Z", fill: "#c8d2e8"});
  el("circle", {cx: 944, cy: 190, r: 6, fill: "#ff5a6a"});
  text("STATS", 916, 278, 19, "#c8d2e8", 600, "middle");
  const gear = el("g", {transform: "translate(916 382)"});
  for (let i = 0; i < 8; i++) el("rect", {x: -4, y: -19, width: 8, height: 9, rx: 1.5, fill: "#c8d2e8", transform: `rotate(${i * 45})`}, gear);
  el("circle", {r: 13, fill: "#c8d2e8"}, gear); el("circle", {r: 5, fill: "#141b36"}, gear);
  text("PID", 916, 438, 19, "#c8d2e8", 600, "middle");

  // Step list beside the brain.
  const list = $("stepList");
  const items = STEPS.map(step => {
    const li = document.createElement("li");
    li.innerHTML = `<b style="background:${COLOR[step.kind]}"></b>${step.label}`;
    list.append(li);
    return li;
  });

  const ease = t => t < .5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2;
  let shownStep = -1;
  function showRoute(progress) {
    const t = Math.min(STEPS.length - 1e-6, progress * STEPS.length);
    const index = Math.floor(t), step = STEPS[index], u = ease(t - index);
    // Path: finished moves solid, the current one drawn as far as the robot has gone.
    for (const seg of segments) {
      const k = STEPS.indexOf(seg.step);
      const amount = k < index ? 1 : k > index ? 0 : u;
      seg.live.setAttribute("x2", seg.step.from[0] + (seg.step.end[0] - seg.step.from[0]) * amount);
      seg.live.setAttribute("y2", seg.step.from[1] + (seg.step.end[1] - seg.step.from[1]) * amount);
    }
    const x = step.from[0] + (step.end[0] - step.from[0]) * u, y = step.from[1] + (step.end[1] - step.from[1]) * u;
    let turn = step.h1 - step.h0;
    turn = ((turn + 540) % 360) - 180;
    const h = step.h0 + turn * (step.kind === "turn" ? u : Math.min(1, u * 4));
    robot.setAttribute("transform", `translate(${x} ${y}) rotate(${h})`);
    const inches = v => ((v - 240) / 3.125).toFixed(1);
    odo.textContent = `x ${inches(x)}  y ${(-(y - 240) / 3.125).toFixed(1)}  speed ${step.speed}`;
    bar.setAttribute("width", (336 * (index + u) / STEPS.length).toFixed(1));
    if (index !== shownStep) {
      shownStep = index;
      stepCount.textContent = `STEP ${index + 1} / ${STEPS.length}`;
      stepLabel.textContent = step.label;
      stepLabel.setAttribute("fill", COLOR[step.kind]);
      arrow.setAttribute("stroke", COLOR[step.kind]);
      arrow.setAttribute("transform", `translate(516 287) rotate(${step.kind === "reverse" ? 180 : step.kind === "turn" ? 90 : 0})`);
      tag13.querySelector("rect").setAttribute("fill", index <= 3 ? "#3cc9f0" : "#0e1530");
      tag13.querySelector("text").setAttribute("fill", index <= 3 ? "#04122a" : "#e8eefc");
      tag46.querySelector("rect").setAttribute("fill", index >= 4 && index <= 7 ? "#3cc9f0" : "#0e1530");
      tag46.querySelector("text").setAttribute("fill", index >= 4 && index <= 7 ? "#04122a" : "#e8eefc");
      items.forEach((li, k) => { li.className = k < index ? "done" : k === index ? "now" : ""; });
    }
  }

  // ---- Scroll-linked motion -----------------------------------------------------------------
  const heroInner = $("heroInner"), tilt = $("tiltDevice"), play = $("play"), rail = $("progress");
  const clamp = v => Math.max(0, Math.min(1, v));
  function onScroll() {
    scrolled = scrollY;
    const vh = innerHeight;
    const max = document.documentElement.scrollHeight - vh;
    rail.style.transform = `scaleX(${max > 0 ? scrollY / max : 0})`;
    if (!still) {
      const h = clamp(scrollY / (vh * .8));
      heroInner.style.transform = `translateY(${h * -90}px) scale(${1 - h * .12})`;
      heroInner.style.opacity = String(1 - h * 1.1);
      const box = tilt.getBoundingClientRect();
      const t = clamp(1 - (box.top - vh * .12) / (vh * .85));
      tilt.style.transform = `rotateX(${(1 - t) * 38}deg) translateY(${(1 - t) * 60}px) scale(${.82 + t * .18})`;
    }
    const area = play.getBoundingClientRect();
    showRoute(clamp(-area.top / (area.height - vh)));
  }
  addEventListener("scroll", onScroll, {passive: true});
  addEventListener("resize", onScroll);
  onScroll();

  if (still) { drawFluid(0); return; }
  const loop = time => { drawFluid(time); requestAnimationFrame(loop); };
  requestAnimationFrame(loop);
})();
