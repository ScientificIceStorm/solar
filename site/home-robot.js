// Solar front page: a VEX robot with a double-reverse four-bar (DR4B) lift, drawn as white
// halftone dots. The lift rises and lowers; dots scatter away from the cursor and spring back.
(() => {
  const canvas = document.getElementById("homeRobot");
  if (!canvas) return;
  const W = 560, H = 360, GAP = 8, MAX_R = 3.9;
  const cols = Math.floor(W / GAP), rows = Math.floor(H / GAP);
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const g = canvas.getContext("2d");
  // The robot is drawn at grid resolution, so each pixel's alpha is the coverage of one dot cell.
  const shape = document.createElement("canvas");
  shape.width = cols;
  shape.height = rows;
  const s = shape.getContext("2d", {willReadFrequently:true});

  const dots = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    const x = (c + .5) * GAP, y = (r + .5) * GAP;
    dots.push({hx:x, hy:y, x, y, vx:0, vy:0, size:0});
  }

  let scale = 1;
  function resize() {
    const ratio = Math.min(devicePixelRatio || 1, 2);
    const box = canvas.getBoundingClientRect();
    scale = box.width / W || 1;
    canvas.width = Math.round(W * scale * ratio);
    canvas.height = Math.round(H * scale * ratio);
    g.setTransform(scale * ratio, 0, 0, scale * ratio, 0, 0);
  }

  const line = (ax, ay, bx, by, width, alpha = 1) => {
    s.globalAlpha = alpha;
    s.lineWidth = width;
    s.beginPath(); s.moveTo(ax, ay); s.lineTo(bx, by); s.stroke();
  };
  const disc = (x, y, radius, alpha = 1) => {
    s.globalAlpha = alpha;
    s.beginPath(); s.arc(x, y, radius, 0, Math.PI * 2); s.fill();
  };
  const box = (x, y, w, h, alpha = 1) => { s.globalAlpha = alpha; s.fillRect(x, y, w, h); };

  // Side view in a 560 x 360 frame. lift: 0 = down, 1 = fully raised.
  function drawRobot(lift) {
    s.setTransform(1 / GAP, 0, 0, 1 / GAP, 0, 0);
    s.clearRect(0, 0, W, H);
    s.fillStyle = s.strokeStyle = "#fff";
    s.lineCap = "round";
    // Drivetrain: chassis rail, wheels, and the battery/brain block.
    box(140, 298, 280, 22);
    for (const x of [176, 280, 384]) { disc(x, 322, 25, .62); disc(x, 322, 9, 1); }
    box(300, 268, 82, 30, .7);
    // Base tower.
    box(236, 196, 26, 104, .9);
    const L = 96, gap = 30, px = 249, py = 214;
    const angle = (-18 + 72 * lift) * Math.PI / 180;
    const dx = L * Math.cos(angle), dy = -L * Math.sin(angle);
    // Stage one: two parallel bars forward and up to the middle link.
    const mx = px + dx, my = py + dy;
    line(px, py, mx, my, 11);
    line(px, py + gap, mx, my + gap, 11);
    line(mx, my - 8, mx, my + gap + 8, 13, .9);
    // Stage two: bars back over the base, so the carriage rises straight up.
    const cx = mx - dx, cy = my + dy;
    line(mx, my, cx, cy, 11);
    line(mx, my + gap, cx, cy + gap, 11);
    for (const [x, y] of [[px, py], [px, py + gap], [mx, my], [mx, my + gap], [cx, cy], [cx, cy + gap]]) disc(x, y, 9);
    // Carriage and intake with two rollers, holding a pin.
    line(cx, cy - 10, cx, cy + gap + 10, 14);
    box(cx + 4, cy - 2, 86, 18, .85);
    disc(cx + 92, cy + 7, 15, .7);
    disc(cx + 92, cy + 27, 11, .55);
    s.globalAlpha = .75;
    s.beginPath(); s.moveTo(cx + 118, cy - 18); s.lineTo(cx + 132, cy + 30); s.lineTo(cx + 104, cy + 30); s.closePath(); s.fill();
    // Floor.
    box(40, 348, 480, 3, .45);
  }

  const pointer = {x:-1e4, y:-1e4, active:false};
  function aim(event) {
    const rect = canvas.getBoundingClientRect();
    pointer.x = (event.clientX - rect.left) / scale;
    pointer.y = (event.clientY - rect.top) / scale;
    pointer.active = true;
  }
  canvas.addEventListener("pointermove", aim);
  canvas.addEventListener("pointerdown", aim);
  canvas.addEventListener("pointerleave", () => { pointer.active = false; });

  let visible = true, last = performance.now(), clock = 0;
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; }).observe(canvas);

  function frame(now) {
    requestAnimationFrame(frame);
    if (!visible || !canvas.offsetParent) { last = now; return; }
    const dt = Math.min(.05, (now - last) / 1000);
    last = now;
    if (!still) clock += dt;
    // Up, a pause at the top, down, a pause at the bottom.
    const phase = (clock % 7) / 7;
    const lift = still ? .55 : phase < .38 ? ease(phase / .38) : phase < .5 ? 1 : phase < .88 ? 1 - ease((phase - .5) / .38) : 0;
    drawRobot(lift);
    const coverage = s.getImageData(0, 0, cols, rows).data;
    g.clearRect(0, 0, W, H);
    g.fillStyle = "#fff";
    for (let i = 0; i < dots.length; i++) {
      const dot = dots[i];
      const target = MAX_R * Math.sqrt(coverage[i * 4 + 3] / 255);
      dot.size += (target - dot.size) * Math.min(1, dt * 14);
      if (pointer.active) {
        const ox = dot.x - pointer.x, oy = dot.y - pointer.y, d2 = ox * ox + oy * oy;
        if (d2 < 4900 && d2 > .01) {
          const push = (1 - Math.sqrt(d2) / 70) * 2400 * dt, d = Math.sqrt(d2);
          dot.vx += ox / d * push;
          dot.vy += oy / d * push;
        }
      }
      // Spring home with damping.
      dot.vx += (dot.hx - dot.x) * 26 * dt;
      dot.vy += (dot.hy - dot.y) * 26 * dt;
      dot.vx *= Math.pow(.02, dt);
      dot.vy *= Math.pow(.02, dt);
      dot.x += dot.vx * dt;
      dot.y += dot.vy * dt;
      if (dot.size < .35) continue;
      g.globalAlpha = Math.min(1, .45 + dot.size / MAX_R);
      g.beginPath();
      g.arc(dot.x, dot.y, dot.size, 0, Math.PI * 2);
      g.fill();
    }
    g.globalAlpha = 1;
  }
  const ease = t => t < .5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2;

  resize();
  addEventListener("resize", resize);
  new ResizeObserver(resize).observe(canvas);
  requestAnimationFrame(frame);
})();
