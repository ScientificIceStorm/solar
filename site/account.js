// Account dashboard (/#account): advanced stats for the team you follow (saved on your account
// in profile.js). Everything comes from Solar's public API: OpenSkill history per event
// (/api/team?history=1), skills per event, points for and against, matches against Solar's
// predictions, schedule strength, upcoming events and published ScoutVision analyses.
(() => {
  const root = document.getElementById('accountView');
  if (!root) return;
  const BLUE = '#2a78d6', ORANGE = '#eb6834';
  const el = (tag, attrs = {}, ...children) => {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs)) {
      if (key === 'class') node.className = value; else if (key === 'text') node.textContent = value; else node.setAttribute(key, value);
    }
    node.append(...children.filter((child) => child != null));
    return node;
  };
  const day = (date) => date.toLocaleDateString(undefined, {month: 'short', day: 'numeric'});
  const pct = (value) => Math.round(value * 100) + '%';
  let request = 0;

  // ---- line chart: one axis, 2px lines, 8px markers, crosshair tooltip, table view -------
  function lineChart({title, note, series, format = (v) => v.toFixed(1)}) {
    const all = series.flatMap((s) => s.points);
    const box = el('section', {class: 'account-card account-chart'}, el('h3', {text: title}));
    if (note) box.append(el('p', {class: 'account-note', text: note}));
    if (!all.length) { box.append(el('p', {class: 'account-empty', text: 'No results yet this season.'})); return box; }
    const W = 640, H = 230, L = 46, R = series.length > 1 ? 118 : 24, T = 14, B = 30;
    let t0 = Math.min(...all.map((p) => p.t)), t1 = Math.max(...all.map((p) => p.t));
    if (t0 === t1) { t0 -= 864e5 * 3; t1 += 864e5 * 3; }
    let v0 = Math.min(...all.map((p) => p.v)), v1 = Math.max(...all.map((p) => p.v));
    const pad = Math.max(1, (v1 - v0) * .12), floor = v0 >= 0 ? 0 : -Infinity;
    v0 = Math.max(floor, v0 - pad); v1 += pad;
    const x = (t) => L + (t - t0) / (t1 - t0) * (W - L - R), y = (v) => H - B - (v - v0) / (v1 - v0) * (H - T - B);
    const svgNS = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(svgNS, 'svg');
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`); svg.setAttribute('class', 'account-svg'); svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', title);
    const add = (tag, attrs, text) => {
      const node = document.createElementNS(svgNS, tag);
      for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
      if (text != null) node.textContent = text;
      svg.append(node); return node;
    };
    for (let i = 0; i <= 4; i++) {
      const v = v0 + (v1 - v0) * i / 4;
      add('line', {x1: L, x2: W - R, y1: y(v), y2: y(v), class: 'grid'});
      add('text', {x: L - 8, y: y(v) + 4, 'text-anchor': 'end', class: 'tick'}, format(v));
    }
    const dates = [...new Set(all.map((p) => p.t))].sort((a, b) => a - b);
    const step = Math.ceil(dates.length / 6);
    dates.forEach((t, i) => { if (i % step === 0 || i === dates.length - 1) add('text', {x: x(t), y: H - 9, 'text-anchor': 'middle', class: 'tick'}, day(new Date(t))); });
    for (const s of series) {
      const pts = [...s.points].sort((a, b) => a.t - b.t);
      if (pts.length > 1) add('path', {d: 'M' + pts.map((p) => `${x(p.t).toFixed(1)},${y(p.v).toFixed(1)}`).join('L'), stroke: s.color, class: 'line'});
      for (const p of pts) add('circle', {cx: x(p.t), cy: y(p.v), r: 4, fill: s.color, class: 'dot'});
      if (series.length > 1 && pts.length) {
        const last = pts.at(-1);
        add('line', {x1: x(last.t) + 8, x2: x(last.t) + 20, y1: y(last.v), y2: y(last.v), stroke: s.color, 'stroke-width': 2});
        add('text', {x: x(last.t) + 24, y: y(last.v) + 4, class: 'label'}, s.name);
      }
    }
    const hair = add('line', {x1: 0, x2: 0, y1: T, y2: H - B, class: 'hair', visibility: 'hidden'});
    const hit = add('rect', {x: L, y: T, width: W - L - R, height: H - T - B, fill: 'transparent', tabindex: 0});
    const tip = el('div', {class: 'account-tip', hidden: ''});
    const showAt = (t) => {
      hair.setAttribute('x1', x(t)); hair.setAttribute('x2', x(t)); hair.setAttribute('visibility', 'visible');
      const date = new Date(t);
      const first = series.flatMap((s) => s.points).find((p) => p.t === t);
      tip.replaceChildren(el('b', {text: first?.label || day(date)}));
      for (const s of series) {
        const p = s.points.find((point) => point.t === t);
        if (!p) continue;
        tip.append(el('div', {class: 'account-tip-row'}, el('i', {style: 'background:' + s.color}),
          el('strong', {text: format(p.v)}), el('span', {text: ' ' + s.name + (p.note ? ' · ' + p.note : '')})));
      }
      tip.hidden = false;
      tip.style.left = Math.min(78, Math.max(0, x(t) / W * 100 - 10)) + '%';
    };
    const nearest = (event) => {
      const rect = svg.getBoundingClientRect(), px = (event.clientX - rect.left) / rect.width * W;
      return dates.reduce((best, t) => Math.abs(x(t) - px) < Math.abs(x(best) - px) ? t : best, dates[0]);
    };
    let focusIndex = dates.length - 1;
    hit.addEventListener('pointermove', (event) => showAt(nearest(event)));
    hit.addEventListener('pointerleave', () => { tip.hidden = true; hair.setAttribute('visibility', 'hidden'); });
    hit.addEventListener('focus', () => showAt(dates[focusIndex]));
    hit.addEventListener('blur', () => { tip.hidden = true; hair.setAttribute('visibility', 'hidden'); });
    hit.addEventListener('keydown', (event) => {
      if (!['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
      focusIndex = Math.max(0, Math.min(dates.length - 1, focusIndex + (event.key === 'ArrowRight' ? 1 : -1)));
      showAt(dates[focusIndex]); event.preventDefault();
    });
    if (series.length > 1) {
      box.append(el('div', {class: 'account-legend'}, ...series.map((s) =>
        el('span', {}, el('i', {style: 'background:' + s.color}), document.createTextNode(s.name)))));
    }
    box.append(el('div', {class: 'account-plot'}, svg, tip));
    const rows = dates.map((t) => el('tr', {}, el('td', {text: series.flatMap((s) => s.points).find((p) => p.t === t)?.label || day(new Date(t))}),
      ...series.map((s) => { const p = s.points.find((point) => point.t === t); return el('td', {class: 'numeric', text: p ? format(p.v) : '—'}); })));
    box.append(el('details', {class: 'account-table'}, el('summary', {text: 'Table'}),
      el('table', {}, el('thead', {}, el('tr', {}, el('th', {text: 'Event'}), ...series.map((s) => el('th', {class: 'numeric', text: s.name})))),
        el('tbody', {}, ...rows))));
    return box;
  }

  const tile = (label, value, detail) => el('div', {class: 'account-tile'}, el('small', {text: label}),
    el('b', {text: value}), detail ? el('span', {text: detail}) : null);

  async function render(team) {
    const id = ++request;
    const {seasons} = await api('seasons');
    const season = seasons[0].id;
    root.replaceChildren(el('p', {class: 'account-empty', text: 'Loading ' + team + '…'}));
    // The profile first: it makes sure the server holds this team's matches for the history.
    const profile = await api('team', {seasonId: season, number: team});
    const [history, board, upcoming, published] = await Promise.all([
      api('team', {seasonId: season, number: team, history: 1}).catch(() => ({events: []})),
      api('openskill', {seasonId: season, gradeLevel: 'All'}).catch(() => ({rows: []})),
      api('team', {seasonId: season, number: team, upcoming: 1}).catch(() => ({events: []})),
      fetch('/api/scoutvision/matches?team=' + encodeURIComponent(team)).then((r) => r.ok ? r.json() : {matches: []}).catch(() => ({matches: []})),
    ]);
    if (id !== request) return;
    if (history.loading) setTimeout(() => { if (id === request && location.hash === '#account') render(team); }, 15000);
    const info = profile.team || {number: team};
    const ratingOf = new Map((board.rows || []).map((row) => [row.teamNumber, row.skill?.rating]));
    const me = (board.rows || []).find((row) => row.teamNumber === team);
    const played = (profile.matches || []).filter((m) => m.completed && m.alliances.every((a) => Number.isInteger(a.score)));
    const side = (m) => m.alliances.find((a) => a.teams.some((t) => t.number.toUpperCase() === team));
    const other = (m) => m.alliances.find((a) => a !== side(m));

    // Matches against Solar's predictions (scored qualification and elimination matches).
    let wins = 0, expected = 0, counted = 0;
    for (const m of played) {
      const mine = side(m), them = other(m);
      if (!mine || !them) continue;
      const chance = m.forecast?.[mine.color];
      if (Number.isFinite(chance)) { expected += chance; counted++; wins += mine.score > them.score ? 1 : mine.score === them.score ? .5 : 0; }
    }
    // Schedule strength from end-of-season OpenSkill ratings.
    const mean = (values) => values.length ? values.reduce((a, b) => a + b, 0) / values.length : null;
    const opponents = mean(played.flatMap((m) => other(m)?.teams || []).map((t) => ratingOf.get(t.number)).filter(Number.isFinite));
    const partners = mean(played.flatMap((m) => (side(m)?.teams || []).filter((t) => t.number.toUpperCase() !== team)).map((t) => ratingOf.get(t.number)).filter(Number.isFinite));

    // Per-event points for and against.
    const events = new Map((profile.events || []).map((event) => [event.id, event]));
    const perEvent = new Map();
    for (const m of played) {
      const mine = side(m), them = other(m), t = new Date(m.started || m.scheduled || events.get(m.event.id)?.start || 0).getTime();
      if (!mine || !them || !t) continue;
      const row = perEvent.get(m.event.id) || {t, scored: [], conceded: [], name: m.event.name};
      row.t = Math.max(row.t, t); row.scored.push(mine.score); row.conceded.push(them.score);
      perEvent.set(m.event.id, row);
    }
    const short = (name) => String(name || '').split(':')[0].slice(0, 46);

    // Skills per event (best driver and programming run at each event).
    const skillPoints = {driver: [], programming: []};
    await Promise.all([...events.values()].filter((event) => new Date(event.start) <= new Date()).map(async (event) => {
      try {
        const data = await api('event', {sku: event.sku, scouting: 1});
        for (const type of ['driver', 'programming']) {
          const best = Math.max(-1, ...(data.skills || []).filter((row) => row.type === type && row.team?.number?.toUpperCase() === team).map((row) => row.score));
          if (best >= 0) skillPoints[type].push({t: new Date(event.start).getTime(), v: best, label: short(event.name)});
        }
      } catch {}
    }));
    if (id !== request) return;

    const skillsRow = me ? [me.combinedScore, me.programmingScore, me.driverScore] : [];
    const rating = me?.skill || profile.skill;   // season-wide OpenSkill, as on the leaderboard
    root.replaceChildren(
      el('div', {class: 'account-head'},
        el('div', {}, el('p', {class: 'account-kicker', text: 'Your team'}),
          el('h1', {id: 'accountTitle'}, document.createTextNode(team + ' '), el('span', {text: info.name || info.teamName || ''})),
          el('p', {class: 'account-sub', text: [info.organization, [info.location?.city, info.location?.region].filter(Boolean).join(', ')].filter(Boolean).join(' · ')})),
        el('a', {class: 'account-link', href: '/team/' + encodeURIComponent(team) + '?season=' + season, text: 'Full team page →'})),
      el('div', {class: 'account-tiles'},
        tile('Solar rank', me ? '#' + me.rank : '—', me ? 'of ' + board.rows.length + ' · score ' + me.score.toFixed(1) : 'Not rated yet'),
        tile('OpenSkill', rating ? rating.rating.toFixed(1) : '—', rating ? 'μ ' + rating.mean.toFixed(1) + ' ± ' + (3 * rating.uncertainty).toFixed(1) + ' · season-wide' : null),
        tile('Record', rating ? [rating.wins, rating.losses, rating.draws].join('–') : '—', rating?.matches ? pct(rating.wins / rating.matches) + ' won' : null),
        tile('Wins vs Solar’s forecast', counted ? wins.toFixed(wins % 1 ? 1 : 0) + ' / ' + expected.toFixed(1) : '—', counted ? (wins >= expected ? '+' : '') + (wins - expected).toFixed(1) + ' over ' + counted + ' matches' : null),
        tile('Best skills', skillsRow[0] ? String(skillsRow[0]) : '—', skillsRow[0] ? 'driver ' + skillsRow[2] + ' · programming ' + skillsRow[1] : null),
        tile('Schedule strength', Number.isFinite(opponents) ? opponents.toFixed(1) : '—', Number.isFinite(partners) ? 'avg opponent · partners ' + partners.toFixed(1) : 'avg opponent OpenSkill'),
      ),
      el('div', {class: 'account-grid'},
        lineChart({title: 'OpenSkill after each event', note: history.loading ? 'Solar is still loading this season’s results; this chart fills in shortly.' :
          'Conservative rating (μ − 3σ) with only the results known at that point. Hover for rank.',
          series: [{name: 'OpenSkill', color: BLUE, points: (history.events || []).filter((row) => Number.isFinite(row.rating)).map((row) => ({
            t: new Date(row.date).getTime(), v: row.rating, label: short(row.name), note: row.rank ? 'rank #' + row.rank + ' of ' + row.rated : ''}))}]}),
        lineChart({title: 'Skills by event', note: 'Best driver and programming runs at each event.', format: (v) => String(Math.round(v)),
          series: [{name: 'Driver', color: BLUE, points: skillPoints.driver}, {name: 'Programming', color: ORANGE, points: skillPoints.programming}]}),
        lineChart({title: 'Points per match by event', note: 'Average alliance score for and against.', format: (v) => v.toFixed(0),
          series: [{name: 'Scored', color: BLUE, points: [...perEvent.values()].map((row) => ({t: row.t, v: mean(row.scored), label: short(row.name)}))},
            {name: 'Conceded', color: ORANGE, points: [...perEvent.values()].map((row) => ({t: row.t, v: mean(row.conceded), label: short(row.name)}))}]}),
        recentMatches(played, side, other, season),
        upcomingCard(upcoming.events || [], season),
        analysesCard(published.matches || []),
      ),
    );
  }

  function recentMatches(played, side, other, season) {
    const card = el('section', {class: 'account-card'}, el('h3', {text: 'Recent matches vs Solar’s forecast'}));
    const rows = [...played].sort((a, b) => new Date(b.started || b.scheduled) - new Date(a.started || a.scheduled)).slice(0, 10);
    if (!rows.length) { card.append(el('p', {class: 'account-empty', text: 'No scored matches yet.'})); return card; }
    card.append(el('table', {class: 'account-matches'}, el('tbody', {}, ...rows.map((m) => {
      const mine = side(m), them = other(m), chance = m.forecast?.[mine.color];
      const result = mine.score > them.score ? 'W' : mine.score < them.score ? 'L' : 'T';
      return el('tr', {}, el('td', {text: m.name}), el('td', {class: 'account-muted', text: String(m.event.name || '').split(':')[0].slice(0, 28)}),
        el('td', {class: 'numeric', text: mine.score + '–' + them.score}),
        el('td', {class: 'numeric', text: Number.isFinite(chance) ? pct(chance) : '—'}),
        el('td', {class: 'result result-' + result, text: result}));
    }))));
    return card;
  }
  function upcomingCard(events, season) {
    const card = el('section', {class: 'account-card'}, el('h3', {text: 'Upcoming events'}));
    if (!events.length) { card.append(el('p', {class: 'account-empty', text: 'No upcoming registrations.'})); return card; }
    card.append(el('ul', {class: 'account-list'}, ...events.slice(0, 6).map((event) => el('li', {},
      el('a', {href: '/event/' + encodeURIComponent(event.sku), text: String(event.name).split(':')[0]}),
      el('span', {class: 'account-muted', text: ' · ' + new Date(event.start).toLocaleDateString()})))));
    return card;
  }
  function analysesCard(rows) {
    const card = el('section', {class: 'account-card'}, el('h3', {text: 'ScoutVision analyses'}));
    if (!rows.length) {
      card.append(el('p', {class: 'account-empty'}, document.createTextNode('No published analyses of your matches yet. '),
        el('a', {href: '/scoutvision/import/', text: 'Analyze a match →'})));
      return card;
    }
    card.append(el('ul', {class: 'account-list'}, ...rows.slice(0, 10).map((row) => el('li', {},
      el('a', {href: '/scoutvision/replay/?match=' + row.id, text: row.r + ' · ' + row.ev}),
      el('span', {class: 'account-muted', text: row.o ? ' · ' + row.o.join('–') : ''})))));
    return card;
  }

  function signedOut(message) {
    const button = el('button', {type: 'button', class: 'account-button', text: 'Sign in'});
    button.onclick = (event) => { event.stopPropagation(); window.solarProfile?.open(true); };
    root.replaceChildren(el('div', {class: 'account-card account-welcome'},
      el('h1', {id: 'accountTitle', text: 'Your team dashboard'}),
      el('p', {text: message}), button));
  }

  async function show() {
    root.hidden = false;
    try { await window.solarProfile?.connect(); } catch (error) { signedOut(error.message); return; }
    const session = window.solarProfile?.session;
    if (!session) return signedOut('Sign in and pick your team to see its rating, skills and results over the season.');
    const team = String(session.user.user_metadata?.team || '').toUpperCase();
    if (!team) return signedOut('Add your team number in the Profile panel (Your team → Save) to build your dashboard.');
    render(team).catch((error) => root.replaceChildren(el('p', {class: 'account-empty', text: error.message})));
  }
  window.solarAccount = {show};
  window.solarProfile?.onChange(() => { if (location.hash === '#account') show(); });
  if (location.hash === '#account') show();
})();
