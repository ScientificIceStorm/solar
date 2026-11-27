// Solar front page: a VEX V5 robot with a 6-bar lift, side-on, drawn as halftone dots.
//
// A 6-bar is two parallelogram four-bars stacked on a floating middle bar. Stage 1 pivots on
// the tower and swings up and forward; stage 2 is geared to it on the middle bar and swings the
// opposite way, so the claw rises almost straight up over the robot while every vertical bar
// stays vertical. Folded it fits inside the 18" start size; raised it reaches the 50" limit.
// The lift cycles on its own; the dots scatter away from the pointer and spring back.
(() => {
  const canvas = document.getElementById("homeRobot");
  if (!canvas) return;
  const W = 560, H = 360, CELL = 5, MAX_R = 2.55;
  const cols = Math.floor(W / CELL), rows = Math.floor(H / CELL);
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const g = canvas.getContext("2d");
  // The robot is drawn at dot resolution: a pixel's alpha is how much of one dot's cell the
  // robot covers there, and its colour is the colour of that part.
  const shape = document.createElement("canvas");
  shape.width = cols;
  shape.height = rows;
  const s = shape.getContext("2d", {willReadFrequently: true});

  const dots = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    const x = (c + .5) * CELL, y = (r + .5) * CELL;
    dots.push({hx: x, hy: y, x, y, vx: 0, vy: 0, size: 0, rgb: -1, fill: "#fff"});
  }

  // Robot units are inches, y up from the floor.
  const PX = 6.1, FLOOR = 342, ORIGIN = 238;
  const X = x => ORIGIN + x * PX, Y = y => FLOOR - y * PX;
  const L1 = 17, L2 = 15.5, TOWER = 3, LOW = 7.5, GAP = 3.6, MAX_ANGLE = 58 * Math.PI / 180;
  const WHITE = "#ffffff", GEAR = "#ff6f63", PIN = "#ffd23c", BATTERY = "#a9d2ff", LIMIT = "#ff8a80";

  let scale = 1;
  function resize() {
    const ratio = Math.min(devicePixelRatio || 1, 2);
    const box = canvas.getBoundingClientRect();
    scale = box.width / W || 1;
    canvas.width = Math.round(W * scale * ratio);
    canvas.height = Math.round(H * scale * ratio);
    g.setTransform(scale * ratio, 0, 0, scale * ratio, 0, 0);
  }

  // Drawing into the dot mask, in inches.
  function bar(ax, ay, bx, by, width = 1.3, alpha = 1, color = WHITE) {
    s.globalAlpha = alpha;
    s.strokeStyle = color;
    s.lineWidth = width * PX;
    s.beginPath(); s.moveTo(X(ax), Y(ay)); s.lineTo(X(bx), Y(by)); s.stroke();
  }
  function disc(x, y, radius, alpha = 1, color = WHITE) {
    s.globalAlpha = alpha;
    s.fillStyle = color;
    s.beginPath(); s.arc(X(x), Y(y), radius * PX, 0, Math.PI * 2); s.fill();
  }
  function hole(x, y, radius) {
    s.globalCompositeOperation = "destination-out";
    disc(x, y, radius, .75);
    s.globalCompositeOperation = "source-over";
  }
  function gear(x, y, radius) {
    disc(x, y, radius, .95, GEAR);
    hole(x, y, radius * .32);
  }

  // The lift linkage for a stage-1 angle (radians above horizontal).
  function linkage(angle) {
    const c = Math.cos(angle), n = Math.sin(angle);
    const a0 = [TOWER, LOW], a1 = [TOWER, LOW + GAP];                     // tower pivots
    const m0 = [a0[0] + L1 * c, a0[1] + L1 * n], m1 = [a1[0] + L1 * c, a1[1] + L1 * n];
    const m2 = [m1[0], m1[1] + 1.2], m3 = [m1[0], m1[1] + 1.2 + GAP];       // stage-2 pivots on the middle bar
    const e0 = [m2[0] - L2 * c, m2[1] + L2 * n], e1 = [m3[0] - L2 * c, m3[1] + L2 * n];
    return {a0, a1, m0, m1, m2, m3, e0, e1};
  }

  function drawRobot(lift) {
    s.setTransform(1 / CELL, 0, 0, 1 / CELL, 0, 0);
    s.clearRect(0, 0, W, H);
    s.globalCompositeOperation = "source-over";
    s.lineCap = "round";
    s.lineJoin = "round";
    const angle = lift * MAX_ANGLE;
    const {a0, a1, m0, m1, m2, m3, e0, e1} = linkage(angle);

    // Floor and the 50" height limit.
    bar(-16, -.3, 28, -.3, .45, .5);
    for (let x = -14; x < 26; x += 2.6) bar(x, 50, x + 1.2, 50, .4, .8, LIMIT);

    // Drivetrain: wheels under a sloped chassis, battery and a pneumatic cylinder.
    for (const x of [0, 7.5, 15]) { disc(x, 1.9, 1.9, .6); disc(x, 1.9, .6); }
    s.globalAlpha = .92;
    s.fillStyle = WHITE;
    s.beginPath();
    s.moveTo(X(-2.5), Y(1.2)); s.lineTo(X(18), Y(1.2)); s.lineTo(X(18.5), Y(3.2));
    s.quadraticCurveTo(X(14), Y(4.6), X(9), Y(5)); s.lineTo(X(-1.2), Y(5)); s.lineTo(X(-2.8), Y(3.4));
    s.closePath(); s.fill();
    for (const [x, y] of [[1, 3.2], [5, 3.4], [9, 3.3], [13, 3]]) hole(x, y, .42);
    s.globalAlpha = .95;
    s.fillStyle = BATTERY;
    s.fillRect(X(-1), Y(7.4), 4.4 * PX, 2.3 * PX);
    bar(-3, 8, 1.2, 8, .9, .8);

    // Intake arms down to the floor at the front and back.
    bar(13, 4.6, 22.5, 13.5, 1.1, .9);
    bar(-6.5, 13, 1.8, 4.6, 1.1, .9);
    gear(17.5, 2.6, 1.1);

    // Tower with its brace and the lift's driven gear.
    bar(TOWER, 4.6, TOWER, a1[1] + 1.6, 1.35);
    bar(TOWER, 6.2, 9.5, 4.8, .9, .8);
    gear(a0[0], a0[1], 2.1);

    // Stage 1: tower up to the middle bar.
    bar(a0[0], a0[1], m0[0], m0[1]);
    bar(a1[0], a1[1], m1[0], m1[1]);

    // Middle bar, with the meshing gears that drive stage 2 the opposite way.
    bar(m0[0], m0[1] - .3, m3[0], m3[1] + .5, 1.35);
    gear(m1[0] + 1.75, m1[1] - .6, 1.6);
    gear(m2[0] + 1.75, m3[1] - .5, 1.6);

    // Stage 2: middle bar back over the robot to the end bar.
    bar(m2[0], m2[1], e0[0], e0[1]);
    bar(m3[0], m3[1], e1[0], e1[1]);

    // End bar and claw, holding a pin.
    bar(e0[0], e0[1] - .4, e1[0], e1[1] + 2.4, 1.35);
    const top = e1[1] + 2.4;
    bar(e1[0] - .2, top, e1[0] + 6.5, top, 1.1);
    bar(e1[0] + 6.5, top, e1[0] + 6.5, top - 3.2, 1);
    const pin = [e1[0] + 4.3, top - 1.2];
    s.globalAlpha = 1;
    s.fillStyle = PIN;
    s.beginPath();
    s.moveTo(X(pin[0] - 1.15), Y(pin[1])); s.lineTo(X(pin[0] + 1.15), Y(pin[1]));
    s.lineTo(X(pin[0] + .42), Y(pin[1] + 2.6)); s.lineTo(X(pin[0] - .42), Y(pin[1] + 2.6));
    s.closePath(); s.fill();

    // Pivot holes through every joint of the linkage.
    for (const p of [a0, a1, m0, m1, m2, m3, e0, e1]) hole(p[0], p[1], .38);
  }

  const pointer = {x: -1e4, y: -1e4, active: false};
  function aim(event) {
    const rect = canvas.getBoundingClientRect();
    pointer.x = (event.clientX - rect.left) / scale;
    pointer.y = (event.clientY - rect.top) / scale;
    pointer.active = true;
  }
  canvas.addEventListener("pointermove", aim);
  canvas.addEventListener("pointerdown", aim);
  canvas.addEventListener("pointerleave", () => { pointer.active = false; });

  // Rest folded, lift, hold at full height, lower.
  const ease = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  function cycle(t) {
    const p = t % 7.2;
    if (p < 1.1) return 0;
    if (p < 3.6) return ease((p - 1.1) / 2.5);
    if (p < 4.9) return 1;
    return 1 - ease((p - 4.9) / 2.3);
  }

  function paint(dt, settle) {
    const cover = s.getImageData(0, 0, cols, rows).data;
    g.clearRect(0, 0, W, H);
    for (let i = 0; i < dots.length; i++) {
      const dot = dots[i], k = i * 4, alpha = cover[k + 3] / 255;
      const target = MAX_R * Math.sqrt(alpha);
      dot.size = settle ? target : dot.size + (target - dot.size) * Math.min(1, dt * 14);
      if (alpha > .05) {
        const rgb = cover[k] << 16 | cover[k + 1] << 8 | cover[k + 2];
        if (rgb !== dot.rgb) { dot.rgb = rgb; dot.fill = `rgb(${cover[k]},${cover[k + 1]},${cover[k + 2]})`; }
      }
      if (!settle) {
        if (pointer.active) {
          const ox = dot.x - pointer.x, oy = dot.y - pointer.y, d2 = ox * ox + oy * oy;
          if (d2 < 4900 && d2 > .01) {
            const d = Math.sqrt(d2), push = (1 - d / 70) * 2400 * dt;
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
      }
      if (dot.size < .3) continue;
      g.globalAlpha = Math.min(1, .45 + dot.size / MAX_R);
      g.fillStyle = dot.fill;
      g.beginPath();
      g.arc(dot.x, dot.y, dot.size, 0, Math.PI * 2);
      g.fill();
    }
    g.globalAlpha = 1;
    g.fillStyle = LIMIT;
    g.font = "600 11px Manrope, system-ui, sans-serif";
    g.fillText('50" height limit', X(-14), Y(50) - 8);
  }

  let visible = true, last = performance.now(), clock = 0;
  new IntersectionObserver(entries => { visible = entries[0].isIntersecting; }).observe(canvas);
  function frame(now) {
    requestAnimationFrame(frame);
    if (!visible || !canvas.offsetParent) { last = now; return; }
    const dt = Math.min(.05, (now - last) / 1000);
    last = now;
    clock += dt;
    drawRobot(cycle(clock));
    paint(dt, false);
  }

  resize();
  const redraw = () => { resize(); if (still) { drawRobot(.62); paint(0, true); } };
  addEventListener("resize", redraw);
  new ResizeObserver(redraw).observe(canvas);
  if (still) redraw();
  else requestAnimationFrame(frame);
})();
