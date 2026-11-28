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
  const showStat = (index) => {
    if (index === statShown) return;
    statShown = index;
    statShots.forEach((img, k) => img.classList.toggle("on", k === index));
    statTabs.forEach((li, k) => li.classList.toggle("now", k === index));
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

  if (still) { drawFluid(0); return; }
  const loop = time => { drawFluid(time); requestAnimationFrame(loop); };
  requestAnimationFrame(loop);
})();
