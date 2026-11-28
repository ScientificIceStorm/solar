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

  // ---- The brain playing the route: the real screen recording, scrubbed by scroll -----------
  // route-frames.webp holds the recording's 114 frames (480 x 240, ten to a row); each step of
  // the route starts at the frame listed beside it.
  const FRAMES = 114, COLS = 10, FW = 480, FH = 240;
  const STEPS = [
    ["DRIVE TO 1", "drive", 0], ["TURN 180°", "turn", 5], ["DRIVE TO 2", "drive", 11], ["BACK TO 3", "back", 22],
    ["TURN 135°", "turn", 31], ["DRIVE TO 4", "drive", 35], ["TURN -90°", "turn", 51], ["DRIVE TO 5", "drive", 58],
    ["BACK TO 6", "back", 68], ["TURN -135°", "turn", 76], ["DRIVE TO 7", "drive", 80], ["TURN 0°", "turn", 96],
    ["DRIVE TO 8", "drive", 104],
  ];
  const COLOR = {drive: "#3cc9f0", back: "#f6a13a", turn: "#9b8cff"};
  const brain = $("brain"), b = brain.getContext("2d");
  const sheet = new Image();
  sheet.decoding = "async";
  sheet.src = "/vision-ui/route-frames.webp";
  let ready = false, wanted = 0, drawn = -1;
  function drawFrame(index) {
    wanted = index;
    if (!ready || index === drawn) return;
    drawn = index;
    b.imageSmoothingQuality = "high";
    b.drawImage(sheet, (index % COLS) * FW, Math.floor(index / COLS) * FH, FW, FH, 0, 0, brain.width, brain.height);
  }
  sheet.decode().catch(() => {}).finally(() => { ready = sheet.naturalWidth > 0; drawn = -1; drawFrame(wanted); });

  const list = $("stepList");
  const items = STEPS.map(([label, kind]) => {
    const li = document.createElement("li");
    li.innerHTML = `<b style="background:${COLOR[kind]}"></b>${label}`;
    list.append(li);
    return li;
  });
  let shownStep = -1;
  function showRoute(progress) {
    const frame = Math.min(FRAMES - 1, Math.floor(progress * FRAMES));
    drawFrame(frame);
    let step = 0;
    while (step + 1 < STEPS.length && STEPS[step + 1][2] <= frame) step++;
    if (step !== shownStep) {
      shownStep = step;
      items.forEach((li, k) => { li.className = k < step ? "done" : k === step ? "now" : ""; });
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

  // ---- Stats tab: scroll (or tap a tab) to flip through the brain's five stats pages -------
  const stats = $("stats"), statShots = [...document.querySelectorAll("#statsDevice img")], statTabs = [...document.querySelectorAll("#statTabs li")];
  let statShown = 0;
  // The tab highlight slides between tabs on the bar laid over the screenshots (tabs sit at
  // x = 16 + 170 i, 160 wide, on an 872-wide bar).
  const barHighlight = document.querySelector("#statBar i");
  const showStat = (index) => {
    if (index === statShown) return;
    statShown = index;
    statShots.forEach((img, k) => img.classList.toggle("on", k === index));
    statTabs.forEach((li, k) => li.classList.toggle("now", k === index));
    const left = (16 + 170 * index) / 872 * 100, right = (872 - 176 - 170 * index) / 872 * 100;
    barHighlight.style.clipPath = `inset(14.29% ${right.toFixed(2)}% 14.29% ${left.toFixed(2)}% round 7px)`;
  };
  const onStatsScroll = () => {
    const area = stats.getBoundingClientRect();
    const progress = clamp(-area.top / (area.height - innerHeight));
    showStat(Math.min(statShots.length - 1, Math.floor(progress * statShots.length)));
  };
  addEventListener("scroll", onStatsScroll, {passive: true});
  addEventListener("resize", onStatsScroll);
  document.getElementById("statTabs").addEventListener("click", (event) => {
    const button = event.target.closest("button[data-tab]");
    if (!button) return;
    const index = Number(button.dataset.tab), span = stats.offsetHeight - innerHeight;
    scrollTo({top: stats.offsetTop + span * (index + .5) / statShots.length, behavior: still ? "auto" : "smooth"});
    showStat(index);
  });
  onStatsScroll();

  // ---- PID tab: the test run plots itself as the page scrolls ---------------------------------
  // The response curve traced from the brain screenshot (screen pixels), redrawn over the plot.
  const CURVE = [84,368.5,90,367.5,96,364.5,102,362.5,108,359.5,114,355.5,120,351.5,126,345.5,132,341.5,138,335.5,144,329.5,150,323.5,156,317.5,162,310.5,168,303.5,174,297.5,180,291.5,186,285.5,192,279.5,198,273.5,204,267.5,210,263.5,216,257.5,222,253.5,228,249.5,234,245.5,240,242,246,238.5,252,235.5,258,232.5,264,230.5,270,228.5,276,226.5,282,224.5,288,223.5,294,222.5,300,221.5,306,220.5,312,219.5,318,219.5,324,219.5,330,219.5,336,219.5,342,219.5,348,219.5,354,219.5,360,219.5,366,219.5,372,219.5,378,219.5,384,219.5,390,219.5,396,219.5,402,219.5,408,219.5,414,220.5,420,221.5,426,221.5,432,221.5,438,221.5,444,221.5,450,221.5,456,221.5,462,221.5,468,222.5,474,223.5,480,223.5,486,223.5,492,223.5,498,223.5,504,223.5,510,223.5,516,223.5,522,223.5,528,223.5,534,223.5,540,223.5,546,223.5,552,223.5,558,223.5,564,223.5,570,223.5,576,223.5,582,223.5,588,223.5,594,223.5,600,223.5,606,223.5,612,223.5,618,223.5,624,223.5,630,223.5,636,223.5,642,223.5,648,223.5,654,223.5,660,223.5,666,223.5,672,223.5,678,223.5,684,223.5,690,223.5,696,223.5,702,223.5,708,223.5,714,223.5,720,223.5,726,223.5,732,223.5,738,223.5,744,223.5,750,223.5,756,223.5,762,223.5,768,223.5,774,223.5,780,223.5,786,223.5,792,223.5,798,223.5,804,223.5,807,223.5];
  const pidArea = $("pid"), pidCanvas = $("pidPlot"), pc = pidCanvas.getContext("2d");
  const pidSteps = [...document.querySelectorAll("#pidSteps li")];
  let pidShown = -1;
  function drawPid(progress) {
    const run = clamp((progress - .3) / .5), done = run >= 1;
    pc.clearRect(0, 0, 960, 480);
    pc.fillStyle = "#0c1430";
    pc.fillRect(82, 179, 758, 197);                       // plot area
    pc.fillStyle = "#152250";
    for (const y of [188, 248, 308, 368]) pc.fillRect(84, y, 754, 2);
    pc.fillStyle = "#ffb547";
    for (let x = 84; x < 836; x += 20) pc.fillRect(x, 224, Math.min(12, 836 - x), 2);
    const end = 84 + (807 - 84) * run;
    pc.strokeStyle = "#37d5f4"; pc.lineWidth = 4; pc.lineJoin = pc.lineCap = "round";
    pc.beginPath();
    let head = null;
    for (let i = 0; i < CURVE.length; i += 2) {
      let x = CURVE[i], y = CURVE[i + 1];
      if (x > end) {
        const px = CURVE[i - 2], py = CURVE[i - 1], k = (end - px) / (x - px);
        x = end; y = py + (y - py) * k;
      }
      i ? pc.lineTo(x, y) : pc.moveTo(x, y);
      head = [x, y];
      if (x >= end) break;
    }
    if (run > 0) pc.stroke();
    if (run > 0 && !done) {
      pc.fillStyle = "#dffbff"; pc.shadowColor = "#37d5f4"; pc.shadowBlur = 14;
      pc.beginPath(); pc.arc(head[0], head[1], 6, 0, Math.PI * 2); pc.fill();
      pc.shadowBlur = 0;
    }
    if (!done) {
      // Hide the results until the run finishes.
      pc.fillStyle = "#0c1430";
      for (const x of [26, 202, 378]) pc.fillRect(x, 440, 150, 26);
      pc.fillStyle = "#04060c";
      pc.fillRect(546, 406, 320, 56);
      if (run > 0) {
        pc.fillStyle = "#b8c5df";
        pc.font = "500 17px Manrope, system-ui, sans-serif";
        pc.fillText("Running drive test…", 552, 431);
        pc.fillStyle = "#56658a";
        pc.fillText(`${(run * 2.45).toFixed(2)} s`, 552, 456);
      }
    }
    const step = progress < .12 ? 0 : progress < .3 ? 1 : !done ? 2 : 3;
    if (step !== pidShown) { pidShown = step; pidSteps.forEach((li, k) => { li.className = k < step ? "done" : k === step ? "now" : ""; }); }
  }
  const onPidScroll = () => {
    const area = pidArea.getBoundingClientRect();
    drawPid(clamp(-area.top / (area.height - innerHeight)));
  };
  addEventListener("scroll", onPidScroll, {passive: true});
  addEventListener("resize", onPidScroll);
  onPidScroll();

  if (still) { drawFluid(0); return; }
  const loop = time => { drawFluid(time); requestAnimationFrame(loop); };
  requestAnimationFrame(loop);
})();
