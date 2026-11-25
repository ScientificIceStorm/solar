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

  // Side view of an Override robot in a 560 x 360 frame, modelled on a real
  // competition bot: big wheels behind a patterned skirt, a tall tower braced
  // with crossing bars, a roller on top, a cylinder mechanism at the back and
  // a long arm down the front. lift: 0 = arm down at the floor, 1 = arm raised.
  function drawRobot(lift) {
    s.setTransform(1 / GAP, 0, 0, 1 / GAP, 0, 0);
    s.clearRect(0, 0, W, H);
    s.globalCompositeOperation = "source-over";
    s.fillStyle = s.strokeStyle = "#fff";
    s.lineCap = "round";
    s.lineJoin = "round";
    // Wheels and chassis rails.
    for (const x of [176, 282, 388]) { disc(x, 318, 27, .6); disc(x, 318, 8, 1); }
    box(150, 266, 280, 14);
    box(150, 284, 280, 8, .8);
    // Patterned skirt across the bottom front (the waves read as lighter dots).
    s.globalAlpha = .85;
    s.beginPath(); s.moveTo(158, 300); s.lineTo(436, 300); s.lineTo(446, 342); s.lineTo(150, 342); s.closePath(); s.fill();
    s.globalCompositeOperation = "destination-out";
    for (const offset of [0, 13]) {
      s.globalAlpha = .55;
      s.lineWidth = 5;
      s.beginPath();
      for (let x = 160; x <= 440; x += 6) s.lineTo(x, 316 + offset + 6 * Math.sin((x + offset * 3) / 26));
      s.stroke();
    }
    s.globalCompositeOperation = "source-over";
    // Cylinder mechanism at the back, tied into the tower.
    box(150, 196, 46, 70, .7);
    s.globalAlpha = .8;
    s.beginPath(); s.ellipse(173, 196, 23, 8, 0, 0, Math.PI * 2); s.fill();
    line(196, 214, 236, 206, 7, .9);
    // Tower: two uprights braced with crossing bars, some running past them.
    line(236, 266, 236, 70, 12);
    line(306, 266, 306, 84, 12);
    for (const [top, bottom] of [[84, 136], [136, 190], [190, 244]]) {
      line(236, bottom, 306, top, 8, .9);
      line(306, bottom, 236, top, 8, .9);
    }
    line(204, 122, 330, 74, 7, .85);
    line(200, 170, 236, 156, 7, .85);
    line(306, 150, 348, 132, 6, .75);
    // Team plate.
    box(318, 224, 88, 40, .55);
    // Roller wheel on top of the tower.
    disc(306, 70, 19, .95);
    disc(306, 70, 6, 1);
    // Long arm from the top of the tower down the front; it swings up and down.
    const px = 312, py = 92, length = 158;
    const angle = (58 - 70 * lift) * Math.PI / 180;
    const ex = px + length * Math.cos(angle), ey = py + length * Math.sin(angle);
    const nx = -Math.sin(angle) * 9, ny = Math.cos(angle) * 9;
    line(px, py, ex, ey, 9);
    line(px + nx, py + ny, ex + nx, ey + ny, 5, .8);
    disc(px, py, 9);
    disc(ex + nx / 2, ey + ny / 2, 12, .9);
    // A thin brace from the chassis up to the arm.
    line(392, 266, px + (ex - px) * .55, py + (ey - py) * .55, 5, .7);
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
