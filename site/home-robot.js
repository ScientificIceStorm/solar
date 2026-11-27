// Solar front page: a VEX V5 robot with a 6-bar lift, drawn side-on like a CAD sketch.
//
// A 6-bar is two parallelogram four-bars stacked on a floating middle bar. Stage 1 pivots on
// the tower and swings up and forward; stage 2 is geared to it on the middle bar and swings the
// opposite way, so the claw rises almost straight up over the robot while every vertical bar
// stays vertical. Folded it fits inside the 18" start size; raised it reaches the 50" limit.
// The lift cycles on its own; hovering the robot makes the lift follow the pointer.
(() => {
  const canvas = document.getElementById("homeRobot");
  if (!canvas) return;
  const W = 560, H = 360;
  const g = canvas.getContext("2d");
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // Field units are inches; y up from the floor.
  const PX = 6.1, FLOOR = 342, ORIGIN = 238;
  const X = x => ORIGIN + x * PX, Y = y => FLOOR - y * PX;
  const L1 = 17, L2 = 15.5, TOWER = 3, LOW = 7.5, GAP = 3.6, MAX_ANGLE = 58 * Math.PI / 180;

  const BAR = "#f3f6fd", EDGE = "#c9d3e6", HOLE = "rgba(20,45,100,.5)", GEAR = "#e0483f",
    BRACE = "#3dbb6b", METAL = "#b9c3d4";

  let scale = 1;
  function resize() {
    const ratio = Math.min(devicePixelRatio || 1, 2);
    const box = canvas.getBoundingClientRect();
    scale = box.width / W || 1;
    canvas.width = Math.round(W * scale * ratio);
    canvas.height = Math.round(H * scale * ratio);
    g.setTransform(scale * ratio, 0, 0, scale * ratio, 0, 0);
  }

  // A C-channel bar between two points (inches), with its row of holes.
  function channel(ax, ay, bx, by, width = 1.05, color = BAR) {
    const x1 = X(ax), y1 = Y(ay), x2 = X(bx), y2 = Y(by);
    g.lineCap = "round";
    g.strokeStyle = EDGE; g.lineWidth = width * PX + 1.6;
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
    g.strokeStyle = color; g.lineWidth = width * PX;
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
    const length = Math.hypot(bx - ax, by - ay), holes = Math.floor(length / .5);
    g.fillStyle = HOLE;
    for (let i = 1; i < holes; i++) {
      const t = i / holes;
      g.fillRect(x1 + (x2 - x1) * t - 1.1, y1 + (y2 - y1) * t - 1.1, 2.2, 2.2);
    }
  }
  function pivot(x, y) {
    g.fillStyle = "#4a5a78";
    g.beginPath(); g.arc(X(x), Y(y), 2.4, 0, Math.PI * 2); g.fill();
    g.fillStyle = BAR;
    g.beginPath(); g.arc(X(x), Y(y), 1, 0, Math.PI * 2); g.fill();
  }
  function gear(x, y, radius, turn, teeth = 24) {
    const cx = X(x), cy = Y(y), r = radius * PX;
    g.fillStyle = GEAR;
    g.beginPath();
    for (let i = 0; i < teeth * 2; i++) {
      const a = turn + i * Math.PI / teeth, rr = i % 2 ? r : r * .9;
      g.lineTo(cx + rr * Math.cos(a), cy + rr * Math.sin(a));
    }
    g.closePath(); g.fill();
    g.strokeStyle = "rgba(90,10,10,.45)"; g.lineWidth = 1;
    for (let i = 0; i < 6; i++) {
      const a = turn + i * Math.PI / 3;
      g.beginPath(); g.moveTo(cx + r * .22 * Math.cos(a), cy + r * .22 * Math.sin(a));
      g.lineTo(cx + r * .7 * Math.cos(a), cy + r * .7 * Math.sin(a)); g.stroke();
    }
    g.fillStyle = "#7a1d18";
    g.beginPath(); g.arc(cx, cy, r * .16, 0, Math.PI * 2); g.fill();
  }
  function wheel(x, y, radius, spin) {
    const cx = X(x), cy = Y(y), r = radius * PX;
    g.fillStyle = "#3b4558"; g.beginPath(); g.arc(cx, cy, r, 0, Math.PI * 2); g.fill();
    g.strokeStyle = METAL; g.lineWidth = 2;
    g.beginPath(); g.arc(cx, cy, r * .72, 0, Math.PI * 2); g.stroke();
    for (let i = 0; i < 5; i++) {
      const a = spin + i * 2 * Math.PI / 5;
      g.beginPath(); g.moveTo(cx, cy); g.lineTo(cx + r * .72 * Math.cos(a), cy + r * .72 * Math.sin(a)); g.stroke();
    }
  }

  // The lift linkage for a stage-1 angle (radians above horizontal).
  function linkage(angle) {
    const c = Math.cos(angle), s = Math.sin(angle);
    const a0 = [TOWER, LOW], a1 = [TOWER, LOW + GAP];                 // tower pivots
    const m0 = [a0[0] + L1 * c, a0[1] + L1 * s], m1 = [a1[0] + L1 * c, a1[1] + L1 * s];
    const m2 = [m1[0], m1[1] + 1.2], m3 = [m1[0], m1[1] + 1.2 + GAP];   // stage-2 pivots on the middle bar
    const e0 = [m2[0] - L2 * c, m2[1] + L2 * s], e1 = [m3[0] - L2 * c, m3[1] + L2 * s];
    return {a0, a1, m0, m1, m2, m3, e0, e1};
  }

  function drawRobot(lift, time) {
    g.clearRect(0, 0, W, H);
    const angle = lift * MAX_ANGLE;
    const {a0, a1, m0, m1, m2, m3, e0, e1} = linkage(angle);

    // 50" height limit, as in a CAD check.
    g.setLineDash([7, 6]); g.strokeStyle = "rgba(255,120,110,.75)"; g.lineWidth = 1.4;
    g.beginPath(); g.moveTo(X(-14), Y(50)); g.lineTo(X(26), Y(50)); g.stroke();
    g.setLineDash([]);
    g.fillStyle = "rgba(255,150,140,.95)"; g.font = "600 11px Manrope, system-ui, sans-serif";
    g.fillText('50" height limit', X(-14), Y(50) - 5);

    // Floor.
    g.strokeStyle = "rgba(255,255,255,.55)"; g.lineWidth = 1.5;
    g.beginPath(); g.moveTo(X(-16), Y(0)); g.lineTo(X(28), Y(0)); g.stroke();

    // Drivetrain: wheels, the sloped chassis, battery and a pneumatic cylinder.
    const spin = still ? 0 : time * .4;
    for (const x of [0, 7.5, 15]) wheel(x, 1.9, 1.9, spin);
    g.fillStyle = "#e7ecf5"; g.strokeStyle = EDGE; g.lineWidth = 1.5;
    g.beginPath();
    g.moveTo(X(-2.5), Y(1.2)); g.lineTo(X(18), Y(1.2)); g.lineTo(X(18.5), Y(3.2));
    g.quadraticCurveTo(X(14), Y(4.6), X(9), Y(5)); g.lineTo(X(-1.2), Y(5)); g.lineTo(X(-2.8), Y(3.4)); g.closePath();
    g.fill(); g.stroke();
    g.fillStyle = HOLE;
    for (const [x, y] of [[1, 3.3], [5, 3.6], [9, 3.4], [13, 3.1]]) { g.beginPath(); g.arc(X(x), Y(y), 1.6, 0, Math.PI * 2); g.fill(); }
    g.fillStyle = "#9cc6ee"; g.strokeStyle = "#6f9fcd";
    g.beginPath(); g.roundRect(X(-1), Y(7.4), 4.4 * PX, 2.3 * PX, 4); g.fill(); g.stroke();
    g.fillStyle = METAL; g.fillRect(X(-3), Y(8.6), 4.2 * PX, 1.2 * PX);
    g.fillStyle = "#d4453d"; g.fillRect(X(1.2), Y(8.45), 3.3 * PX, .9 * PX);

    // Intake arms down to the floor, front and back.
    channel(13, 4.6, 22.5, 13.5, .95);
    channel(-6.5, 13, 1.8, 4.6, .95);
    gear(17.5, 2.6, 1.15, -time * 2.4, 14);

    // Tower with a brace and the lift motor's gear.
    channel(TOWER, 4.6, TOWER, a1[1] + 1.6, 1.1);
    channel(TOWER, 6.2, 9.5, 4.8, .8);
    gear(TOWER + 1.6, a0[1] - .2, 1.15, -angle * 3.2, 12);
    gear(a0[0], a0[1], 2.1, angle * 1.5);

    // Stage 1 (tower to middle bar), with braces along its arms.
    channel(a0[0], a0[1], m0[0], m0[1]);
    channel(a1[0], a1[1], m1[0], m1[1]);
    const brace = (p, q, from, to) => {
      const n = [-(q[1] - p[1]), q[0] - p[0]], len = Math.hypot(...n), off = .75 / len;
      const at = t => [p[0] + (q[0] - p[0]) * t + n[0] * off, p[1] + (q[1] - p[1]) * t + n[1] * off];
      const [s0, s1] = [at(from), at(to)];
      channel(s0[0], s0[1], s1[0], s1[1], .55, BRACE);
    };
    brace(a1, m1, .35, .7);

    // Middle bar with the two meshing gears that drive stage 2 the opposite way.
    channel(m0[0], m0[1] - .3, m3[0], m3[1] + .5, 1.1);
    gear(m1[0] + 1.75, m1[1] - .6, 1.75, -angle * 2.2);
    gear(m2[0] + 1.75, m3[1] - .5, 1.75, angle * 2.2 + .13);

    // Stage 2 (middle bar back over the robot to the end bar).
    channel(m2[0], m2[1], e0[0], e0[1]);
    channel(m3[0], m3[1], e1[0], e1[1]);
    brace(e1, m3, .3, .65);

    // End bar and claw, holding a pin.
    channel(e0[0], e0[1] - .4, e1[0], e1[1] + 2.4, 1.1);
    const top = e1[1] + 2.4;
    channel(e1[0] - .2, top, e1[0] + 6.5, top, .9);
    channel(e1[0] + 6.5, top, e1[0] + 6.5, top - 3.2, .8);
    gear(e1[0] + 3.2, top - 1.7, .95, -time * 4, 12);
    const px = X(e1[0] + 4.8), py = Y(top - 1.2);
    g.fillStyle = "#ffd23c"; g.strokeStyle = "rgba(120,90,0,.45)";
    g.beginPath(); g.moveTo(px - 7, py); g.lineTo(px + 7, py); g.lineTo(px + 2.5, py - 16); g.lineTo(px - 2.5, py - 16); g.closePath(); g.fill(); g.stroke();
    g.fillStyle = "#e0483f"; g.fillRect(px - 8, py, 16, 4);

    for (const p of [a0, a1, m0, m1, m2, m3, e0, e1]) pivot(...p);
  }

  // Auto cycle: rest folded, lift, hold, lower. Hovering takes over the lift height.
  const ease = t => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  function cycle(t) {
    const p = t % 7.2;
    if (p < 1.1) return 0;
    if (p < 3.6) return ease((p - 1.1) / 2.5);
    if (p < 4.9) return 1;
    return 1 - ease((p - 4.9) / 2.3);
  }
  let target = null, shown = 0, last = performance.now(), clock = 0;
  canvas.addEventListener("pointermove", event => {
    const box = canvas.getBoundingClientRect();
    const height = (FLOOR - (event.clientY - box.top) / scale) / PX;      // inches above the floor
    target = Math.max(0, Math.min(1, (height - 17) / 30));
  });
  canvas.addEventListener("pointerleave", () => { target = null; });

  function frame(now) {
    const dt = Math.min(.05, (now - last) / 1000);
    last = now;
    clock += dt;
    const goal = target ?? cycle(clock);
    shown += (goal - shown) * Math.min(1, dt * (target === null ? 30 : 7));
    drawRobot(shown, clock);
    requestAnimationFrame(frame);
  }
  resize();
  addEventListener("resize", () => { resize(); if (still) drawRobot(.62, 0); });
  if (still) drawRobot(.62, 0);
  else requestAnimationFrame(frame);
})();
