// ScoutVision scroll intro: a real match (Smoky Mountain Forge, Semifinal 1-1, as ScoutVision read
// it) replayed on a drawn field. Scrolling moves the camera from the stands to straight overhead
// and around the field while the match clock runs: robots get boxed, tracked, then the goals and
// toggles fill in and each play is credited. The last screen hands over to the hub below.
(() => {
  const intro = document.getElementById("svIntro");
  if (!intro) return;
  const canvas = document.getElementById("svField"), g = canvas.getContext("2d");
  const $ = (id) => document.getElementById(id);
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
  const ease = (t) => t * t * (3 - 2 * t);
  const lerp = (a, b, t) => a + (b - a) * t;
  // 0 below a, rising to 1 by b, holding to c, gone by d.
  const band = (p, a, b, c, d) => p <= a || p >= d ? 0 : p < b ? ease((p - a) / (b - a)) : p <= c ? 1 : ease(1 - (p - c) / (d - c));

  const PIN = ["#ff5d5d", "#4ea8ff", "#ffd23f"], PIN_SIDE = ["#b8323a", "#2468b8", "#b8901c"];
  const TEAM = {red: "#ff6b6b", blue: "#5cb2ff"}, TEAM_SIDE = {red: "#8f2730", blue: "#1f4f8c"};
  const OWNER = {1: "#ff5d5d", 2: "#4ea8ff", 3: "#9aa8bd"};
  const WALL_AT = {far: [72, 0], left: [0, 72], right: [144, 72], near: [72, 144]};
  const WALL_DIR = {far: [1, 0], left: [0, 1], right: [0, 1], near: [1, 0]};

  // Camera keyframes over scroll progress: elevation (90 = overhead), yaw, zoom and where the
  // field sits on screen (fractions of the stage).
  const KEYS = [
    [0, {e: 22, yaw: 0, zoom: 1.2, cx: .5, cy: .66}],
    [.1, {e: 30, yaw: 0, zoom: 1, cx: .63, cy: .56}],
    [.27, {e: 33, yaw: 0, zoom: 1.04, cx: .63, cy: .56}],
    [.42, {e: 88, yaw: 0, zoom: .92, cx: .63, cy: .53}],
    [.53, {e: 88, yaw: 0, zoom: .92, cx: .63, cy: .53}],
    [.64, {e: 44, yaw: -26, zoom: 1.08, cx: .63, cy: .56}],
    [.75, {e: 44, yaw: -48, zoom: 1.08, cx: .63, cy: .56}],
    [.87, {e: 58, yaw: -95, zoom: .98, cx: .63, cy: .55}],
    [1, {e: 66, yaw: -135, zoom: .5, cx: .5, cy: .8}],
  ];
  function camera(p, mobile) {
    let i = 0;
    while (i + 2 < KEYS.length && KEYS[i + 1][0] <= p) i++;
    const [p0, a] = KEYS[i], [p1, b] = KEYS[i + 1];
    const t = ease(clamp((p - p0) / (p1 - p0)));
    const cam = {};
    for (const key in a) cam[key] = lerp(a[key], b[key], t);
    if (mobile) { cam.cx = .5; cam.cy = .6 + .12 * (1 - ease(clamp(p / .1))); }
    return cam;
  }

  let match = null;
  fetch("/scoutvision/intro/smoky-match.json?v=1").then((r) => r.json()).then((data) => {
    match = data;
    $("svIntroEvent").textContent = `${data.event} · ${data.round[0]}${data.round.slice(1).toLowerCase()}`;
    $("svIntroFinal").innerHTML = `<b class="r">${data.finalScore[0]}</b> – <b class="b">${data.finalScore[1]}</b>`;
    dirty = true;
  }).catch(() => {});

  // Autonomous plays slowly through the Detect chapter; driver control fills the rest. The
  // break between the two is skipped.
  const frameAt = (p) => p < .28
    ? clamp((p - .08) / .2) * match.autoEnd
    : lerp(match.driverStart, match.driverEnd, clamp((p - .28) / .6));
  const stateAt = (frame) => {
    let found = match.states[0];
    for (const state of match.states) { if (state[0] <= frame) found = state; else break; }
    return found;
  };
  function poseAt(team, frame) {
    const flat = match.tracks[team], n = flat.length / 3;
    const k = clamp(frame / match.step, 0, n - 1), i = Math.floor(k), j = Math.min(n - 1, i + 1), t = k - i;
    const x = lerp(flat[i * 3], flat[j * 3], t), y = lerp(flat[i * 3 + 1], flat[j * 3 + 1], t);
    // Heading from where the robot was a little earlier (tracks carry no rotation).
    let heading = 0;
    for (let back = 2; back < 40; back += 2) {
      const q = Math.max(0, i - back), dx = x - flat[q * 3], dy = y - flat[q * 3 + 1];
      if (dx * dx + dy * dy > 4) { heading = Math.atan2(dy, dx); break; }
      if (q === 0) break;
    }
    return {x, y, heading, estimated: flat[i * 3 + 2] === 2};
  }

  // ---- Projection --------------------------------------------------------------------------
  let W = 0, H = 0, dpr = 1, view = null;
  const D = 300;
  function setView(cam) {
    const mobile = W < 760;
    const fit = Math.min(W * (mobile ? .9 : .54), H * (mobile ? .5 : .66));
    const e = cam.e * Math.PI / 180, yaw = cam.yaw * Math.PI / 180;
    view = {se: Math.sin(e), ce: Math.cos(e), sy: Math.sin(yaw), cy: Math.cos(yaw),
      f: cam.zoom * fit * D / 144, ox: cam.cx * W, oy: cam.cy * H};
  }
  function project(x, y, h = 0) {
    const X = x - 72, Z = y - 72;
    const rx = X * view.cy - Z * view.sy, rz = X * view.sy + Z * view.cy;
    const up = h * view.ce - rz * view.se;
    const depth = D - (h * view.se + rz * view.ce);
    const s = view.f / depth;
    return [view.ox + rx * s, view.oy - up * s, depth, s];
  }
  const poly = (points) => { g.beginPath(); points.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); };

  // ---- Drawing -----------------------------------------------------------------------------
  function drawFloor(p, time) {
    for (let r = 0; r < 6; r++) for (let c = 0; c < 6; c++) {
      poly([project(c * 24, r * 24), project(c * 24 + 24, r * 24), project(c * 24 + 24, r * 24 + 24), project(c * 24, r * 24 + 24)]);
      g.fillStyle = (r + c) % 2 ? "#18243a" : "#1b2942";
      g.fill();
    }
    g.lineWidth = 1;
    g.strokeStyle = "#2f4466";
    for (let k = 0; k <= 6; k++) {
      let a = project(k * 24, 0), b = project(k * 24, 144);
      g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
      a = project(0, k * 24); b = project(144, k * 24);
      g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
    }
    // The camera "finding" the field: a scan line sweeping the floor before the match starts.
    const scan = band(p, -.01, 0, .07, .13);
    if (scan > 0) {
      const y = (time * .045) % 170 - 13;
      const a = clamp(y - 12, 0, 144), b = clamp(y, 0, 144);
      if (b > a) {
        const p0 = project(0, a), p1 = project(144, b);
        const grad = g.createLinearGradient(0, p0[1], 0, p1[1]);
        grad.addColorStop(0, "#3cc9f000"); grad.addColorStop(1, `rgba(60,201,240,${.42 * scan})`);
        poly([project(0, a), project(144, a), project(144, b), project(0, b)]);
        g.fillStyle = grad; g.fill();
        const l0 = project(0, b), l1 = project(144, b);
        g.strokeStyle = `rgba(160,236,255,${.9 * scan})`; g.lineWidth = 2;
        g.beginPath(); g.moveTo(l0[0], l0[1]); g.lineTo(l1[0], l1[1]); g.stroke();
      }
      // Corner locks.
      for (const [x, y] of [[0, 0], [144, 0], [144, 144], [0, 144]]) {
        const [sx, sy] = project(x, y);
        g.strokeStyle = `rgba(160,236,255,${.85 * scan})`; g.lineWidth = 2;
        g.beginPath(); g.arc(sx, sy, 9, 0, Math.PI * 2); g.stroke();
      }
    }
  }

  function drawWalls() {
    const corners = [[0, 0], [144, 0], [144, 144], [0, 144]];
    for (let i = 0; i < 4; i++) {
      const [x0, y0] = corners[i], [x1, y1] = corners[(i + 1) % 4];
      poly([project(x0, y0), project(x1, y1), project(x1, y1, 11), project(x0, y0, 11)]);
      g.fillStyle = "rgba(190,210,240,.07)"; g.fill();
      const a = project(x0, y0, 11), b = project(x1, y1, 11);
      g.strokeStyle = "rgba(200,220,250,.38)"; g.lineWidth = 1.5;
      g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
    }
  }

  function box(x, y, half, h0, h1, heading) {
    const c = Math.cos(heading), s = Math.sin(heading);
    const foot = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([u, v]) => [x + (u * c - v * s) * half, y + (u * s + v * c) * half]);
    return {bottom: foot.map(([fx, fy]) => project(fx, fy, h0)), top: foot.map(([fx, fy]) => project(fx, fy, h1))};
  }

  function drawRobot(robot, alliance) {
    const {bottom, top} = box(robot.x, robot.y, 8, 0, 12, robot.heading);
    const sides = [0, 1, 2, 3].map((i) => {
      const j = (i + 1) % 4;
      return {pts: [bottom[i], bottom[j], top[j], top[i]], depth: (bottom[i][2] + bottom[j][2]) / 2};
    }).sort((a, b) => b.depth - a.depth);
    for (const side of sides) { poly(side.pts); g.fillStyle = TEAM_SIDE[alliance]; g.fill(); }
    poly(top); g.fillStyle = TEAM[alliance]; g.fill();
    g.strokeStyle = "rgba(255,255,255,.55)"; g.lineWidth = 1; g.stroke();
    // Front marker so heading reads.
    const front = project(robot.x + Math.cos(robot.heading) * 7, robot.y + Math.sin(robot.heading) * 7, 12.2);
    g.fillStyle = "#fff"; g.beginPath(); g.arc(front[0], front[1], Math.max(1.5, front[3] * 1.6), 0, Math.PI * 2); g.fill();
    return [...bottom, ...top];
  }

  function drawBoxLabel(points, team, robot, alpha, frame) {
    const xs = points.map((q) => q[0]), ys = points.map((q) => q[1]);
    const x0 = Math.min(...xs) - 4, x1 = Math.max(...xs) + 4, y0 = Math.min(...ys) - 4, y1 = Math.max(...ys) + 4;
    g.save();
    g.globalAlpha = alpha;
    g.strokeStyle = robot.estimated ? "#ffe08a" : "#7cf2c8";
    g.lineWidth = 2;
    if (robot.estimated) g.setLineDash([5, 4]);
    g.strokeRect(x0, y0, x1 - x0, y1 - y0);
    g.setLineDash([]);
    const conf = robot.estimated ? "held" : (.9 + .07 * Math.sin(frame * .07 + team.charCodeAt(2))).toFixed(2);
    const text = `${team} ${conf}`;
    g.font = "700 11px 'Segoe UI Variable','Segoe UI',system-ui,sans-serif";
    const w = g.measureText(text).width + 10;
    g.fillStyle = robot.estimated ? "#ffe08a" : "#7cf2c8";
    g.fillRect(x0 - 1, y0 - 17, w, 17);
    g.fillStyle = "#06121b";
    g.fillText(text, x0 + 4, y0 - 5);
    g.restore();
  }

  function drawTrail(team, frame, alliance, alpha) {
    const span = 150, stepFrames = match.step * 2;
    g.lineCap = "round";
    let prev = null;
    for (let f = Math.max(0, frame - span); f <= frame; f += stepFrames) {
      const robot = poseAt(team, f), point = project(robot.x, robot.y, .3);
      if (prev) {
        g.strokeStyle = alliance === "red" ? `rgba(255,107,107,${alpha * (1 - (frame - f) / span)})` : `rgba(92,178,255,${alpha * (1 - (frame - f) / span)})`;
        g.lineWidth = Math.max(1.5, point[3] * 3.2);
        g.beginPath(); g.moveTo(prev[0], prev[1]); g.lineTo(point[0], point[1]); g.stroke();
      }
      prev = point;
    }
  }

  function drawGoal(goal, stack, pulse, owner, highlight) {
    const [x, y] = goal.point;
    const base = project(x, y, 0);
    const home = goal.id.endsWith("-red") ? "red" : goal.id.endsWith("-blue") ? "blue" : null;
    // Base ring, coloured for alliance goals.
    g.beginPath();
    g.ellipse(base[0], base[1], 7 * base[3], 7 * base[3] * view.se, 0, 0, Math.PI * 2);
    g.fillStyle = home ? (home === "red" ? "rgba(255,93,93,.22)" : "rgba(78,168,255,.22)") : "rgba(200,215,240,.12)";
    g.fill();
    g.strokeStyle = owner ? OWNER[owner] : "rgba(220,230,250,.5)";
    g.lineWidth = 1.5; g.stroke();
    if (pulse > 0) {
      g.beginPath();
      g.ellipse(base[0], base[1], (7 + 14 * (1 - pulse)) * base[3], (7 + 14 * (1 - pulse)) * base[3] * view.se, 0, 0, Math.PI * 2);
      g.strokeStyle = `rgba(255,240,180,${pulse})`; g.lineWidth = 2.5; g.stroke();
    }
    // Pins stacked up the post.
    const r = 2.6, pitch = 3.3;
    stack.forEach((color, i) => {
      const b = project(x, y, 1 + i * pitch), t = project(x, y, 1 + (i + 1) * pitch - .5);
      const rx = r * b[3], ry = rx * view.se, rxt = r * t[3], ryt = rxt * view.se;
      g.fillStyle = PIN_SIDE[color];
      g.beginPath();
      g.moveTo(b[0] - rx, b[1]); g.lineTo(t[0] - rxt, t[1]); g.lineTo(t[0] + rxt, t[1]); g.lineTo(b[0] + rx, b[1]);
      g.ellipse(b[0], b[1], rx, ry, 0, 0, Math.PI);
      g.fill();
      g.fillStyle = PIN[color];
      g.beginPath(); g.ellipse(t[0], t[1], rxt, ryt, 0, 0, Math.PI * 2); g.fill();
    });
    if (highlight > 0 && stack.length) {
      const top = project(x, y, 1 + stack.length * pitch + 4);
      g.save();
      g.globalAlpha = highlight;
      g.font = "800 12px 'Segoe UI Variable','Segoe UI',system-ui,sans-serif";
      const text = String(stack.length);
      const w = g.measureText(text).width + 12;
      g.fillStyle = "rgba(6,12,26,.82)";
      g.beginPath(); g.roundRect(top[0] - w / 2, top[1] - 19, w, 18, 9); g.fill();
      g.fillStyle = "#fff"; g.textAlign = "center"; g.fillText(text, top[0], top[1] - 6);
      g.restore();
    }
  }

  function drawToggle(wall, owner, pulse) {
    const [x, y] = WALL_AT[wall], [dx, dy] = WALL_DIR[wall];
    const a = project(x - dx * 9, y - dy * 9, 12), b = project(x + dx * 9, y + dy * 9, 12);
    g.lineCap = "round";
    if (pulse > 0) {
      g.strokeStyle = `rgba(255,240,180,${pulse * .8})`; g.lineWidth = Math.max(6, a[3] * 9);
      g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
    }
    g.strokeStyle = OWNER[owner] || OWNER[3]; g.lineWidth = Math.max(3, a[3] * 4.5);
    g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke();
  }

  // ---- DOM overlays ------------------------------------------------------------------------
  const chapters = [...intro.querySelectorAll("[data-show]")].map((el) => ({el, range: el.dataset.show.split(",").map(Number)}));
  const hud = $("svHud"), clock = $("svClock"), phase = $("svPhase"), redScore = $("svRed"), blueScore = $("svBlue");
  const feed = $("svFeed"), feedList = $("svFeedList"), dots = [...intro.querySelectorAll(".sv-intro-dots i")];
  let shownPlay = -2, shownClock = "", shownScore = "";
  const mmss = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
  function overlays(p, frame) {
    for (const {el, range: [a, b, c, d]} of chapters) {
      const v = band(p, a, b, c, d);
      el.style.opacity = v.toFixed(3);
      el.style.transform = `translateY(${(1 - v) * (p < (b + c) / 2 ? 28 : -28)}px)`;
      el.style.visibility = v > .01 ? "visible" : "hidden";
    }
    const step = p < .09 ? 0 : p < .29 ? 1 : p < .53 ? 2 : p < .75 ? 3 : p < .89 ? 4 : 5;
    dots.forEach((dot, i) => dot.classList.toggle("on", i === step));
    hud.style.opacity = band(p, .06, .1, .88, .93).toFixed(3);
    feed.style.opacity = band(p, .55, .6, .88, .92).toFixed(3);
    if (!match) return;
    const state = stateAt(frame);
    const ended = frame >= match.driverEnd - 1;
    const score = ended ? match.finalScore : state[1];
    const scoreText = score.join();
    if (scoreText !== shownScore) { shownScore = scoreText; redScore.textContent = score[0]; blueScore.textContent = score[1]; }
    const text = ended ? "FINAL" : frame <= match.autoEnd ? `AUTO ${mmss((match.autoEnd - frame) / match.fps)}` : `DRIVER ${mmss((match.driverEnd - frame) / match.fps)}`;
    if (text !== shownClock) { shownClock = text; clock.textContent = text; phase.className = frame <= match.autoEnd ? "auto" : ended ? "final" : "driver"; }
    let last = -1;
    match.plays.forEach((play, i) => { if (play.frame <= frame) last = i; });
    if (last !== shownPlay) {
      shownPlay = last;
      const recent = match.plays.slice(Math.max(0, last - 3), last + 1).reverse();
      feedList.innerHTML = recent.map((play, i) => {
        const t = play.frame <= match.autoEnd ? `A ${mmss(play.frame / match.fps)}` : mmss((play.frame - match.driverStart) / match.fps + 15);
        const swing = play.points ? play.points[0] - play.points[1] : 0;
        const tone = swing > 0 ? "r" : swing < 0 ? "b" : "";
        const actor = play.actor ? `<b>${play.actor}</b>` : `<b class="q">Unattributed</b>`;
        const what = `${play.title.replace(" stack change", "").replace(" changes", "")}, ${play.detail.toLowerCase()}`;
        return `<li class="${i === 0 ? "new" : ""}"><time>${t}</time>${actor}<span>${what}</span><em class="${tone}">${swing ? `+${Math.abs(swing)}` : "±0"}</em></li>`;
      }).join("") || "<li class=\"wait\">Waiting for the first play…</li>";
    }
  }

  // ---- Frame loop --------------------------------------------------------------------------
  let target = 0, current = 0, dirty = true, visible = true;
  function progress() {
    const box = intro.getBoundingClientRect();
    return clamp(-box.top / (box.height - innerHeight));
  }
  function fit() {
    // The stage slides up under Solar's floating header.
    const mast = document.querySelector("header.masthead")?.offsetHeight || 0;
    intro.style.setProperty("--mast", `${mast}px`);
    intro.style.marginTop = `${-mast}px`;
    dpr = Math.min(2, devicePixelRatio || 1);
    W = canvas.clientWidth; H = canvas.clientHeight;
    canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
    dirty = true;
  }
  function render(p, time) {
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, W, H);
    intro.style.setProperty("--dark", (1 - ease(clamp((p - .9) / .1))).toFixed(3));
    const cam = camera(p, W < 760);
    setView(cam);
    const frame = match ? frameAt(p) : 0;
    g.globalAlpha = 1 - clamp((p - .93) / .07) * .65;
    drawFloor(p, time);
    drawWalls();
    if (match) {
      const state = stateAt(frame);
      const trail = band(p, .3, .36, .88, .94);
      const boxes = band(p, .08, .12, .4, .47);
      const counts = band(p, .55, .6, .9, .95);
      const robots = match.teams.map(({team, alliance}) => ({team, alliance, pose: poseAt(team, frame)}));
      if (trail > 0) robots.forEach(({team, alliance}) => drawTrail(team, frame, alliance, trail * .85));
      match.walls.forEach((wall, i) => {
        const flip = match.plays.find((play) => play.wall === wall && play.frame <= frame && frame - play.frame < 40);
        drawToggle(wall, state[3][i], flip ? 1 - (frame - flip.frame) / 40 : 0);
      });
      // Painter's order: farthest first.
      const things = [
        ...match.goals.map((goal, i) => ({depth: project(goal.point[0], goal.point[1])[2], draw: () => {
          const recent = match.plays.find((play) => play.goals?.includes(goal.id) && play.kind === "stack" && play.frame <= frame && frame - play.frame < 45);
          drawGoal(goal, state[2][i], recent ? 1 - (frame - recent.frame) / 45 : 0, null, counts);
        }})),
        ...robots.map((robot) => ({depth: project(robot.pose.x, robot.pose.y)[2], draw: () => {
          const corners = drawRobot(robot.pose, robot.alliance);
          if (boxes > 0) drawBoxLabel(corners, robot.team, robot.pose, boxes, frame);
        }})),
      ].sort((a, b) => b.depth - a.depth);
      things.forEach((thing) => thing.draw());
    }
    g.globalAlpha = 1;
    overlays(p, frame);
  }
  function loop(time) {
    target = progress();
    const before = current;
    current = still ? target : current + (target - current) * .14;
    if (Math.abs(target - current) < .0004) current = target;
    // Keep drawing while the scan line runs on the opening screen; otherwise only when moving.
    if (visible && (dirty || current !== before || current < .14)) { dirty = false; render(current, time); }
    requestAnimationFrame(loop);
  }
  new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; dirty = true; }).observe(intro);
  addEventListener("resize", fit);
  fit();
  current = target = progress();
  requestAnimationFrame(loop);
  $("svSkip").addEventListener("click", (event) => {
    event.preventDefault();
    scrollTo({top: intro.offsetTop + intro.offsetHeight - 80, behavior: still ? "auto" : "smooth"});
  });
  window.__svIntro = {render: (p) => { current = target = p; render(p, performance.now()); }};
})();
