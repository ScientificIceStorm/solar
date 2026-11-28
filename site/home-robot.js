// Solar front page: the word "solar" drawn as halftone dots across the first screen.
//
// The letters are rendered once per layout into a small mask (one pixel per dot), so each frame
// only moves dots. On load the dots fly in from scattered positions and settle into the word, a
// soft light sweep passes over it every few seconds, and the dots scatter away from the pointer
// and spring back.
(() => {
  const canvas = document.getElementById("homeRobot");
  if (!canvas) return;
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const g = canvas.getContext("2d");
  const mask = document.createElement("canvas");
  const m = mask.getContext("2d", {willReadFrequently: true});
  const WORD = "solar";

  let W = 0, H = 0, CELL = 7, MAX_R = 3.4, dots = [], left = 0, right = 0, first = true;

  function layout() {
    const box = canvas.getBoundingClientRect();
    if (!box.width || !box.height) return false;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    W = box.width; H = box.height;
    canvas.width = Math.round(W * ratio);
    canvas.height = Math.round(H * ratio);
    g.setTransform(ratio, 0, 0, ratio, 0, 0);
    CELL = W < 700 ? 3 : 3.5;
    MAX_R = CELL * .5;
    const cols = Math.ceil(W / CELL), rows = Math.ceil(H / CELL);
    mask.width = cols; mask.height = rows;

    // A modest word sitting just above the search box.
    const search = document.querySelector(".home-search");
    const bar = search ? search.getBoundingClientRect() : null;
    const top = bar ? bar.top - box.top : H - 130, barWidth = bar && bar.width ? bar.width : Math.min(W * .9, 640);
    m.setTransform(1 / CELL, 0, 0, 1 / CELL, 0, 0);
    m.clearRect(0, 0, W, H);
    m.fillStyle = "#fff";
    m.textAlign = "center";
    m.textBaseline = "alphabetic";
    if ("letterSpacing" in m) m.letterSpacing = "-0.02em";
    let size = 100;
    m.font = `800 ${size}px Manrope, system-ui, sans-serif`;
    const probe = m.measureText(WORD);
    size = barWidth * .5 / (probe.width / size);                     // half as wide as the search bar
    m.font = `800 ${size}px Manrope, system-ui, sans-serif`;
    const width = m.measureText(WORD).width;
    const descent = m.measureText(WORD).actualBoundingBoxDescent || 0;
    const base = top - 18 - descent;
    m.fillText(WORD, W / 2, base);
    left = W / 2 - width / 2; right = W / 2 + width / 2;

    const cover = m.getImageData(0, 0, cols, rows).data;
    const old = dots;
    dots = [];
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const alpha = cover[(r * cols + c) * 4 + 3] / 255;
      if (alpha < .05) continue;
      const hx = (c + .5) * CELL, hy = (r + .5) * CELL;
      dots.push({hx, hy, x: hx, y: hy, vx: 0, vy: 0, target: MAX_R * Math.sqrt(alpha), size: 0});
    }
    // The first time, throw the dots across the screen so they assemble into the word.
    if (first && !still) {
      for (const d of dots) {
        const a = Math.random() * Math.PI * 2, r = (.35 + Math.random() * .65) * Math.max(W, H) * .6;
        d.x = W / 2 + Math.cos(a) * r; d.y = H / 2 + Math.sin(a) * r;
      }
    } else if (old.length) {
      for (const d of dots) d.size = d.target;
    }
    first = false;
    return true;
  }

  // The pointer is followed over the whole page, so the search box doesn't block the effect.
  const pointer = {x: -1e4, y: -1e4, active: false};
  addEventListener("pointermove", event => {
    const rect = canvas.getBoundingClientRect();
    pointer.x = event.clientX - rect.left;
    pointer.y = event.clientY - rect.top;
    pointer.active = pointer.x >= 0 && pointer.y >= 0 && pointer.x <= rect.width && pointer.y <= rect.height;
  }, {passive: true});
  document.addEventListener("pointerleave", () => { pointer.active = false; });

  // A band of light that crosses the word every 6.5 s, slanted slightly.
  function sweep(x, y, t) {
    const p = (t % 6.5) / 2.4;
    if (p > 1) return 0;
    const centre = left - 160 + (right - left + 320) * p, d = (x + (y - H / 2) * .35 - centre) / 90;
    return Math.exp(-d * d);
  }

  function paint(dt, clock, settle) {
    g.clearRect(0, 0, W, H);
    const reach = Math.max(70, CELL * 12), reach2 = reach * reach;
    for (const dot of dots) {
      dot.size = settle ? dot.target : dot.size + (dot.target - dot.size) * Math.min(1, dt * 4);
      if (!settle) {
        if (pointer.active) {
          const ox = dot.x - pointer.x, oy = dot.y - pointer.y, d2 = ox * ox + oy * oy;
          if (d2 < reach2 && d2 > .01) {
            const d = Math.sqrt(d2), push = (1 - d / reach) * 2600 * dt;
            dot.vx += ox / d * push;
            dot.vy += oy / d * push;
          }
        }
        if (dot.vx || dot.vy || dot.x !== dot.hx || dot.y !== dot.hy) {
          dot.vx += (dot.hx - dot.x) * 26 * dt;
          dot.vy += (dot.hy - dot.y) * 26 * dt;
          dot.vx *= Math.pow(.02, dt);
          dot.vy *= Math.pow(.02, dt);
          dot.x += dot.vx * dt;
          dot.y += dot.vy * dt;
          if (Math.abs(dot.vx) + Math.abs(dot.vy) < .01 && Math.abs(dot.x - dot.hx) + Math.abs(dot.y - dot.hy) < .05) {
            dot.vx = dot.vy = 0; dot.x = dot.hx; dot.y = dot.hy;
          }
        }
      }
      const glow = settle ? 0 : sweep(dot.hx, dot.hy, clock);
      const r = dot.size * (1 + glow * .28);
      if (r < .3) continue;
      g.globalAlpha = Math.min(1, .55 + .45 * dot.size / MAX_R);
      g.fillStyle = glow > .08 ? `rgb(255,${255 - glow * 30 | 0},${255 - glow * 120 | 0})` : "#fff";
      g.beginPath();
      g.arc(dot.x, dot.y, r, 0, Math.PI * 2);
      g.fill();
    }
    g.globalAlpha = 1;
  }

  let visible = true, last = performance.now(), clock = 0, ready = false;
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; }).observe(canvas);
  function frame(now) {
    requestAnimationFrame(frame);
    if (!visible || !canvas.offsetParent || !ready) { last = now; return; }
    const dt = Math.min(.05, (now - last) / 1000);
    last = now;
    clock += dt;
    paint(dt, clock, false);
  }
  const redraw = () => {
    ready = layout();
    if (ready && still) paint(0, 0, true);
  };
  // Wait for Manrope so the word isn't measured in the fallback font.
  (document.fonts ? document.fonts.load("800 100px Manrope").catch(() => {}) : Promise.resolve()).then(() => {
    new ResizeObserver(redraw).observe(canvas);
    redraw();
    if (!still) requestAnimationFrame(frame);
  });
})();
