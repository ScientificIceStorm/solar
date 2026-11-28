// Solar front page: a VEX V5 robot raising its 6-bar lift, side-on, drawn as halftone dots
// across the whole first screen.
//
// A 6-bar is two parallelogram four-bars stacked on a floating middle bar: stage 1 pivots on the
// tower and swings up and forward, stage 2 swings back the other way, so the claw rises almost
// straight up while every vertical bar stays vertical. The lift cycles on its own; the dots
// scatter away from the pointer and spring back.
(() => {
  const canvas = document.getElementById("homeRobot");
  if (!canvas) return;
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const g = canvas.getContext("2d");
  const shape = document.createElement("canvas");
  const s = shape.getContext("2d", {willReadFrequently: true});
  const L1 = 17, L2 = 15.5, TOWER = 3, LOW = 7.5, GAP = 3.6, MAX_ANGLE = 58 * Math.PI / 180;
  const WHITE = "#ffffff", PIN = "#ffd23c";

  // Layout in CSS pixels, rebuilt on resize: the dot grid covers the canvas, and the robot is
  // scaled to stand over the search box.
  let W = 0, H = 0, CELL = 7, MAX_R = 3.4, cols = 0, rows = 0, dots = [], PX = 8, FLOOR = 0, ORIGIN = 0;
  const X = x => ORIGIN + x * PX, Y = y => FLOOR - y * PX;

  function layout() {
    const box = canvas.getBoundingClientRect();
    if (!box.width || !box.height) return false;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    W = box.width; H = box.height;
    canvas.width = Math.round(W * ratio);
    canvas.height = Math.round(H * ratio);
    g.setTransform(ratio, 0, 0, ratio, 0, 0);
    CELL = W < 700 ? 5 : W < 1300 ? 6 : 7;
    MAX_R = CELL * .5;
    cols = Math.ceil(W / CELL); rows = Math.ceil(H / CELL);
    shape.width = cols; shape.height = rows;
    dots = [];
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const x = (c + .5) * CELL, y = (r + .5) * CELL;
      dots.push({hx: x, hy: y, x, y, vx: 0, vy: 0, size: 0, fill: WHITE, rgb: -1});
    }
    FLOOR = H - Math.max(120, H * .2);
    PX = Math.min((FLOOR - H * .05) / 50, W * .7 / 30);
    ORIGIN = W / 2 - 8.5 * PX;
    return true;
  }

  function bar(ax, ay, bx, by, width = 1.35, alpha = 1, color = WHITE) {
    s.globalAlpha = alpha;
    s.strokeStyle = color;
    s.lineWidth = width * PX;
    s.beginPath(); s.moveTo(X(ax), Y(ay)); s.lineTo(X(bx), Y(by)); s.stroke();
  }
  function disc(x, y, radius, alpha = 1) {
    s.globalAlpha = alpha;
    s.fillStyle = WHITE;
    s.beginPath(); s.arc(X(x), Y(y), radius * PX, 0, Math.PI * 2); s.fill();
  }
  function hole(x, y, radius) {
    s.globalCompositeOperation = "destination-out";
    disc(x, y, radius, .8);
    s.globalCompositeOperation = "source-over";
  }

  function drawRobot(lift) {
    s.setTransform(1 / CELL, 0, 0, 1 / CELL, 0, 0);
    s.clearRect(0, 0, W, H);
    s.globalCompositeOperation = "source-over";
    s.lineCap = "round";
    s.lineJoin = "round";
    const angle = lift * MAX_ANGLE, c = Math.cos(angle), n = Math.sin(angle);
    const a0 = [TOWER, LOW], a1 = [TOWER, LOW + GAP];
    const m0 = [a0[0] + L1 * c, a0[1] + L1 * n], m1 = [a1[0] + L1 * c, a1[1] + L1 * n];
    const m2 = [m1[0], m1[1] + 1.2], m3 = [m1[0], m1[1] + 1.2 + GAP];
    const e0 = [m2[0] - L2 * c, m2[1] + L2 * n], e1 = [m3[0] - L2 * c, m3[1] + L2 * n];

    bar(-9, -.4, 26, -.4, .4, .45);                                   // floor
    for (const x of [0, 7.5, 15]) { disc(x, 1.9, 1.9, .62); disc(x, 1.9, .6); }
    s.globalAlpha = .92;
    s.fillStyle = WHITE;
    s.beginPath();
    s.moveTo(X(-2.5), Y(1.2)); s.lineTo(X(18), Y(1.2)); s.lineTo(X(18.5), Y(3.2));
    s.quadraticCurveTo(X(14), Y(4.6), X(9), Y(5)); s.lineTo(X(-1.2), Y(5)); s.lineTo(X(-2.8), Y(3.4));
    s.closePath(); s.fill();
    for (const [x, y] of [[1, 3.2], [5, 3.4], [9, 3.3], [13, 3]]) hole(x, y, .42);

    bar(TOWER, 4.6, TOWER, a1[1] + 1.6, 1.4);                         // tower
    bar(TOWER, 6.2, 9.5, 4.8, .9, .8);                                // tower brace
    bar(a0[0], a0[1], m0[0], m0[1]);                                  // stage 1
    bar(a1[0], a1[1], m1[0], m1[1]);
    bar(m0[0], m0[1] - .3, m3[0], m3[1] + .5, 1.4);                   // middle bar
    bar(m2[0], m2[1], e0[0], e0[1]);                                  // stage 2
    bar(m3[0], m3[1], e1[0], e1[1]);
    bar(e0[0], e0[1] - .4, e1[0], e1[1] + 2.4, 1.4);                  // end bar
    const top = e1[1] + 2.4;                                          // claw holding a pin
    bar(e1[0] - .2, top, e1[0] + 6.5, top, 1.1);
    bar(e1[0] + 6.5, top, e1[0] + 6.5, top - 3.2, 1);
    const pin = [e1[0] + 4.3, top - 1.2];
    s.globalAlpha = 1;
    s.fillStyle = PIN;
    s.beginPath();
    s.moveTo(X(pin[0] - 1.15), Y(pin[1])); s.lineTo(X(pin[0] + 1.15), Y(pin[1]));
    s.lineTo(X(pin[0] + .42), Y(pin[1] + 2.6)); s.lineTo(X(pin[0] - .42), Y(pin[1] + 2.6));
    s.closePath(); s.fill();
    for (const p of [a0, a1, m0, m1, m2, m3, e0, e1]) hole(p[0], p[1], .38);
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
    const reach = Math.max(70, CELL * 12), reach2 = reach * reach;
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
      if (dot.size < .3) continue;
      g.globalAlpha = Math.min(1, .45 + dot.size / MAX_R);
      g.fillStyle = dot.fill;
      g.beginPath();
      g.arc(dot.x, dot.y, dot.size, 0, Math.PI * 2);
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
    drawRobot(cycle(clock));
    paint(dt, false);
  }
  const redraw = () => {
    ready = layout();
    if (ready && still) { drawRobot(.62); paint(0, true); }
  };
  new ResizeObserver(redraw).observe(canvas);
  redraw();
  if (!still) requestAnimationFrame(frame);
})();
