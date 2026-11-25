const $ = (id) => document.getElementById(id);
const ui = Object.fromEntries(
  'title searchForm search season grade region lookup count status results pagination range previous next detail home browse footer homeForm homeQuery suggestions jumpNow browsePanel'.split(' ').map((id) => [id, $(id)])
);
const views = {
  skills: ['World Skills', 'Search teams…'],
  teams: ['Teams', 'Team number, name, or school…'],
  insights: ['Insights', 'Find a team, school, or city…'],
  events: ['Events', 'Search events or cities…'],
};
const escape = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[char]);
const locationText = (item = {}) => [item.city, item.region, item.country].filter(Boolean).join(', ');
const pageSize = 20;
let view = 'skills';
let rows = [];
let page = 0;
let loadId = 0;
let detailId = 0;
let searchIndex;
let listError = '';
let loading = false;
let seasonsReady = false;
let jumpToCurrentWeek = false;
let homeSearchTimer;
let eventRefreshTimer;
let teamReplayObserver;
let disconnectEventIndicator;
let browseRefreshTimer;
let webcastIndex = {};
let ratingIndexUpdating = false;
let insightMetric = 'score';
const comparedTeams = new Set();
const pendingApi = new Map();
const isRatingView = () => view === 'teams' || view === 'insights';

function api(path, params) {
  const query = params ? '?' + new URLSearchParams(params) : '';
  const key = path + query;
  if (!pendingApi.has(key)) {
    pendingApi.set(key, fetchApi(path, query).finally(() => pendingApi.delete(key)));
  }
  return pendingApi.get(key);
}

async function fetchApi(path, query) {
  const response = await fetch('/api/' + path + query, {signal: AbortSignal.timeout(25000)});
  if (!response.headers.get('content-type')?.includes('application/json')) {
    throw new Error('Solar data is temporarily unavailable.');
  }
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || 'Could not load data.');
  return data;
}

function status(message, retry) {
  ui.status.textContent = message;
  if (retry) {
    const button = document.createElement('button');
    button.textContent = 'Retry';
    button.type = 'button';
    button.addEventListener('click', retry);
    ui.status.append(' ', button);
  }
}

function switchView() {
  clearTimeout(browseRefreshTimer);
  const route = location.hash.slice(1);
  const detail = location.pathname.match(/^\/(team|event)\/([a-z0-9-]+)$/i);
  const map = !detail && route === 'map';
  $('mapView').hidden = !map;
  ui.home.hidden = Boolean(detail) || map || Object.hasOwn(views, route);
  ui.browse.hidden = Boolean(detail) || !Object.hasOwn(views, route);
  ui.detail.hidden = !detail;
  if (!detail) {
    detailId++;
    clearTimeout(eventRefreshTimer);
    teamReplayObserver?.disconnect();
  }
  ui.footer.hidden = !ui.home.hidden;
  document.body.classList.toggle('home-view', !ui.home.hidden);
  document.querySelectorAll('nav a').forEach((link) => link.removeAttribute('aria-current'));
  if (detail) {
    document.querySelector('nav a[href="/#' + detail[1] + 's"]')?.setAttribute('aria-current', 'page');
    syncNav();
    if (detail[1] === 'event' || seasonsReady || /^\d+$/.test(new URLSearchParams(location.search).get('season') || '')) {
      loadDetail(detail[1], detail[2]);
    }
    return;
  }
  if (map) {
    document.querySelector('.top-nav a[href="/#map"]').setAttribute('aria-current','page');
    loadCaliforniaMap(seasonsReady ? ui.season.value : '', (seasonId) => api('events', {seasonId}));
    syncNav();
    return;
  }
  if (!ui.home.hidden) {
    syncNav();
    return;
  }
  view = route;
  const [title, placeholder] = views[view];
  ui.title.replaceChildren(title);
  const dot = document.createElement('span');
  dot.textContent = '.';
  ui.title.append(dot);
  ui.search.placeholder = placeholder;
  ui.search.setAttribute('aria-label', placeholder.replace('…', ''));
  ui.search.value = '';
  ui.lookup.hidden = view !== 'teams';
  ui.grade.hidden = view === 'events';
  ui.grade.querySelector('[value="All"]').hidden = !isRatingView();
  ui.grade.value = isRatingView() ? 'All' : 'High School';
  ui.region.hidden = view === 'events';
  ui.searchForm.hidden = view === 'events';
  $('eventSearchFallback').hidden = view !== 'events';
  ui.browsePanel.classList.toggle('calendar-mode', view === 'events');
  document.querySelectorAll('nav a').forEach((link) => {
    if (link.hash === '#' + view) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  });
  if (seasonsReady) loadRows();
  syncNav();
}

async function initialize() {
  status('Loading seasons…');
  try {
    const data = await api('seasons');
    const year = new Date().getFullYear();
    const seasonYear = (item) => Number(item.name.match(/20\d{2}/)?.[0]) || 0;
    const seasons = data.seasons.filter((item) => seasonYear(item) <= year)
      .sort((a, b) => seasonYear(b) - seasonYear(a) || b.id - a.id);
    if (!seasons.length) throw new Error('No seasons available.');
    ui.season.replaceChildren(...seasons.map((item) =>
      new Option(item.name.replace(/^VEX (V5 )?Robotics Competition\s*/i, ''), item.id)));
    ui.season.disabled = false;
    seasonsReady = true;
    const explicitTeamSeason = location.pathname.startsWith('/team/') &&
      /^\d+$/.test(new URLSearchParams(location.search).get('season') || '');
    if (explicitTeamSeason) {
      const picker = $('teamSeason');
      if (picker) populateTeamSeasons(picker, picker.value);
    } else switchView();
    if (!ui.home.hidden && ui.homeQuery.value.trim()) searchHome();
  } catch {
    status('Could not load VEX seasons.', initialize);
    if (!ui.detail.hidden && location.pathname.startsWith('/team/') &&
        !/^\d+$/.test(new URLSearchParams(location.search).get('season') || '')) {
      detailError('Could not load seasons.', initialize);
    }
  }
}

async function loadRows() {
  const id = ++loadId;
  clearTimeout(browseRefreshTimer);
  page = 0;
  rows = [];
  webcastIndex = {};
  ratingIndexUpdating = false;
  listError = '';
  loading = true;
  jumpToCurrentWeek = view === 'events';
  ui.region.replaceChildren(new Option('All regions', ''));
  render();
  try {
    const params = {seasonId: ui.season.value};
    if (view !== 'events') params.gradeLevel = ui.grade.value;
    const source = {events:'events', skills:'skills', teams:'openskill', insights:'openskill'}[view];
    const result = await api(source, params);
    if (id !== loadId) return;
    rows = isRatingView() ? result.rows : view === 'skills' ?
      result.sort((a, b) => a.rank - b.rank) : result;
    ratingIndexUpdating = isRatingView() && result.updating;
    if (view !== 'events') {
      const regions = [...new Set(rows.map((row) => row.eventRegion || row.region).filter(Boolean))].sort();
      ui.region.append(...regions.map((region) => new Option(region, region)));
    }
    if (view === 'events') {
      const poll = async () => {
        try {
          const links = await api('webcasts', {seasonId: params.seasonId});
          if (id !== loadId || view !== 'events' || ui.browse.hidden) return;
          webcastIndex = links;
          ui.results.querySelectorAll('[data-webcast-sku]').forEach(updateWebcastBadge);
        } catch {}
        if (id === loadId && view === 'events' && !ui.browse.hidden) {
          browseRefreshTimer = setTimeout(poll, 30000);
        }
      };
      void poll();
    }
  } catch {
    if (id === loadId) listError = 'Could not load ' + (view === 'events' ? 'events' : view === 'teams' ? 'OpenSkill rankings' : 'Skills results') + '.';
  } finally {
    if (id === loadId) {
      loading = false;
      render();
    }
  }
}

function table(columns, body) {
  return '<div class="table-wrap"><table><thead><tr>' +
    columns.map(([label, className = '']) => '<th scope="col" class="' + className + '">' + label + '</th>').join('') +
    '</tr></thead><tbody>' + body.join('') + '</tbody></table></div>';
}

function eventRow(event) {
  const name = escape(event.name);
  const link = event.sku ? eventLink(event.sku, event.name, event.seasonId) : name;
  return '<tr data-row-link><td>' + link + '<span data-webcast-sku="' + escape(event.sku) + '"></span></td><td class="muted">' + escape(locationText(event.location)) +
    '</td><td class="numeric">' + escape(dateRange(event)) + '</td></tr>';
}

function updateWebcastBadge(element) {
  const url = webcastIndex[element.dataset.webcastSku]?.[0];
  if (url && !element.firstChild) element.innerHTML = externalLink(url, 'Webcast');
}

const weekLength = 7 * 86400000;
function weekStart(value) {
  const date = new Date(value);
  if (!value || Number.isNaN(date.valueOf())) return null;
  date.setUTCHours(0, 0, 0, 0);
  date.setUTCDate(date.getUTCDate() - (date.getUTCDay() + 6) % 7);
  return date.valueOf();
}

function jumpList(label, links) {
  return '<aside class="jump-list" aria-label="' + label + '"><h2>' + label + '</h2>' +
    '<div>' + links.map(({id, name, caption}) => '<a href="#' + id + '"><strong>' +
      escape(name) + '</strong><small>' + escape(caption) + '</small></a>').join('') + '</div></aside>';
}

function wireJumps(container) {
  container.querySelector('.jump-list')?.addEventListener('click', (event) => {
    const link = event.target.closest('a');
    if (!link) return;
    event.preventDefault();
    const target = $(link.hash.slice(1));
    target?.scrollIntoView({block: 'start'});
    target?.focus({preventScroll: true});
    container.querySelectorAll('.jump-list a').forEach((item) => {
      if (item === link) item.setAttribute('aria-current', 'location');
      else item.removeAttribute('aria-current');
    });
  });
}

function renderCalendar(events) {
  const weeks = new Map();
  for (const event of events) {
    const start = weekStart(event.start);
    if (!weeks.has(start)) weeks.set(start, []);
    weeks.get(start).push(event);
  }
  const groups = [...weeks].sort(([a], [b]) => (a ?? Infinity) - (b ?? Infinity))
    .map(([start, rows]) => ({
      start, rows, id: 'week-' + (start ?? 'tbd'),
      name: start === null ? 'Dates pending' : 'Week of ' + dateLabel(start),
      caption: rows.length + (rows.length === 1 ? ' event' : ' events'),
    }));
  const now = weekStart(new Date());
  const nearest = groups.find((group) => group.start === now) ||
    groups.find((group) => group.start !== null && group.start > now) ||
    groups.findLast((group) => group.start !== null);
  ui.jumpNow.hidden = !nearest;
  if (nearest) {
    ui.jumpNow.textContent = nearest.start === now ? '↓ This week' : nearest.start > now ? '↓ Next events' : '↓ Latest events';
    ui.jumpNow.onclick = () => ui.results.querySelector('a[href="#' + nearest.id + '"]')?.click();
  }
  $('eventSearchFallback').hidden = true;
  ui.results.innerHTML = '<div class="split-layout"><div class="calendar-rail">' +
    '<button type="button" class="event-search-trigger" data-event-search aria-haspopup="dialog">Search events</button>' +
    jumpList('Season weeks', groups) + '</div>' +
    '<div class="split-content">' + groups.map((group) =>
      '<section class="panel week-card" tabindex="-1" id="' + group.id + '"><div class="section-heading"><h2>' +
      escape(group.name) + '</h2><span>' + escape(group.caption) + '</span></div>' +
      table([['Event'], ['Location'], ['Dates', 'numeric']], group.rows.map(eventRow)) +
      '</section>').join('') + '</div></div>';
  wireJumps(ui.results);
  ui.results.querySelectorAll('[data-webcast-sku]').forEach(updateWebcastBadge);
  if (nearest && jumpToCurrentWeek && !ui.search.value.trim()) {
    jumpToCurrentWeek = false;
    requestAnimationFrame(() => {
      if (view !== 'events' || ui.search.value.trim()) return;
      const link = ui.results.querySelector('a[href="#' + nearest.id + '"]');
      link?.setAttribute('aria-current', 'location');
      $(nearest.id)?.scrollIntoView({behavior: 'instant', block: 'start'});
      if (link && link.offsetParent) {
        const rail = link.closest('.jump-list');
        rail.scrollTop = Math.max(0, link.offsetTop - rail.clientHeight / 2);
      }
    });
  }
}

function render() {
  const query = ui.search.value.trim().toLowerCase();
  const region = ui.region.value;
  const isEvents = view === 'events';
  const isTeams = isRatingView();
  const filtered = rows.filter((row) => {
    if (!isEvents && region && (row.eventRegion || row.region) !== region) return false;
    const fields = isEvents
      ? [row.name, row.sku, locationText(row.location)]
      : [row.teamNumber, row.teamName, row.organization, locationText(row)];
    return fields.join(' ').toLowerCase().includes(query);
  });
  ui.count.textContent = loading || listError ? '' : filtered.length.toLocaleString() + (isEvents ? ' events' : ' teams');
  const start = page * pageSize;
  if (view === 'insights') filtered.sort((a, b) =>
    (insightValue(b, insightMetric) ?? -Infinity) - (insightValue(a, insightMetric) ?? -Infinity) || a.rank - b.rank);
  const visible = filtered.slice(start, start + pageSize);
  ui.pagination.hidden = isEvents || filtered.length <= pageSize;
  ui.jumpNow.hidden = !isEvents || !filtered.length;
  ui.range.textContent = (start + 1) + '–' + Math.min(start + pageSize, filtered.length) + ' of ' + filtered.length.toLocaleString();
  ui.previous.disabled = !page;
  ui.next.disabled = start + pageSize >= filtered.length;
  if (!visible.length) {
    $('eventSearchFallback').hidden = !isEvents;
    ui.results.replaceChildren();
    if (listError) status(listError, loadRows);
    else status(loading ? 'Loading ' + (isEvents ? 'events' : isTeams ? 'OpenSkill rankings' : 'Skills results') + '…' :
      isTeams && ratingIndexUpdating ? 'Indexing season matches…' :
      query ? 'No results match your search.' : isEvents ? 'No events for this season.' : 'No Skills results for these filters.');
    return;
  }
  status('');
  if (isEvents) {
    renderCalendar(filtered);
    return;
  }
  if (isTeams) {
    if (ratingIndexUpdating) status('More season results are being indexed. Reload later to see the next ranking snapshot.', loadRows);
    if (view === 'insights') {
      renderInsights(visible, filtered);
      return;
    }
    ui.results.innerHTML = table(
      [['Rank'], ['Team'], ['Name'], ['Region', 'hide-small'], ['Solar score', 'numeric'], ['OpenSkill', 'numeric'], ['Rated', 'numeric']],
      visible.map((row) => '<tr data-row-link><td>' + shown(row.rank) + '</td><td>' +
        teamLink(row.teamNumber, ui.season.value) + '</td><td>' + escape(row.teamName || row.organization || '—') +
        '</td><td class="hide-small">' + escape(row.eventRegion || row.region || '—') +
        '</td><td class="numeric"><span class="score">' + oneDecimal(row.score ?? row.skill.rating) +
        '</span></td><td class="numeric">' + oneDecimal(row.skill.rating) +
        '</td><td class="numeric">' + shown(row.skill.matches) + '</td></tr>')
    );
    return;
  }
  ui.results.innerHTML = table(
      [['Rank'], ['Team'], ['Name'], ['Region', 'hide-small'], ['Skills', 'numeric'], ['Driver', 'numeric hide-small'], ['Autonomous', 'numeric hide-small']],
      visible.map((row) =>
        '<tr><td class="muted">' + (row.rank > 0 ? escape(row.rank) : '—') + '</td>' +
        '<td>' + teamLink(row.teamNumber, ui.season.value) + '</td>' +
        '<td>' + escape(row.teamName || row.organization || '—') + '</td>' +
        '<td class="muted hide-small">' + escape(row.eventRegion || row.region || row.country || '—') + '</td>' +
        '<td class="numeric"><span class="score">' + escape(row.combinedScore) + '</span></td>' +
        '<td class="numeric hide-small">' + escape(row.driverScore) + '</td>' +
        '<td class="numeric hide-small">' + escape(row.programmingScore) + '</td></tr>')
    );
}

function lookupTeam() {
  const number = ui.search.value.trim().toUpperCase();
  if (seasonsReady && /^[A-Z0-9]{1,12}$/.test(number)) location.href = teamPath(number, ui.season.value);
  else if (seasonsReady) status('Enter an exact team number, such as 98601B.');
}

window.addEventListener('hashchange', switchView);
ui.season.addEventListener('change', loadRows);
ui.grade.addEventListener('change', loadRows);
ui.region.addEventListener('change', () => { page = 0; render(); });
ui.search.addEventListener('input', () => { if (seasonsReady) { page = 0; render(); } });
ui.searchForm.addEventListener('submit', (event) => { event.preventDefault(); if (view === 'teams') lookupTeam(); });
ui.lookup.addEventListener('click', lookupTeam);
ui.previous.addEventListener('click', () => { page--; render(); });
ui.next.addEventListener('click', () => { page++; render(); });


function teamPath(number, season) {
  return '/team/' + encodeURIComponent(number) + (season ? '?season=' + encodeURIComponent(season) : '');
}

function teamLink(number, season) {
  const text = escape(number || 'TBD');
  return /^[A-Z0-9]{1,12}$/i.test(number || '')
    ? '<a class="team-link" href="' + teamPath(number, season) + '">' + text + '</a>' : text;
}

function eventLink(sku, name, season) {
  return /^(RE|VE)-[A-Z0-9-]+$/i.test(sku || '')
    ? '<a class="event-link" href="/event/' + encodeURIComponent(sku) +
      (season ? '?season=' + encodeURIComponent(season) : '') + '">' + escape(name || sku) + '</a>'
    : escape(name || 'Event');
}

async function searchHome() {
  const query = ui.homeQuery.value.trim().toLowerCase();
  ui.suggestions.hidden = query.length < 2;
  if (query.length < 2) return [];
  ui.suggestions.textContent = 'Searching…';
  try {
    if (!seasonsReady) return [];
    const seasonId = ui.season.value;
    searchIndex ??= Promise.allSettled([
      api('skills', {seasonId, gradeLevel: 'High School'}),
      api('skills', {seasonId, gradeLevel: 'Middle School'}),
      api('events', {seasonId}),
    ]);
    const [high, middle, upcoming] = await searchIndex;
    if (query !== ui.homeQuery.value.trim().toLowerCase()) return [];
    const teams = [...(high.value || []), ...(middle.value || [])];
    const matches = [...new Map(teams.map((row) => [row.teamNumber, row])).values()]
      .filter((row) => [row.teamNumber, row.teamName, row.organization].join(' ').toLowerCase().includes(query))
      .sort((a, b) => Number(b.teamNumber.toLowerCase() === query) - Number(a.teamNumber.toLowerCase() === query))
      .slice(0, 5)
      .map((row) => [teamPath(row.teamNumber, seasonId), row.teamNumber, row.teamName, 'TEAM']);
    for (const event of (upcoming.value || []).filter((row) =>
      [row.name, row.sku, locationText(row.location)].join(' ').toLowerCase().includes(query)).slice(0, 4)) {
      matches.push(['/event/' + encodeURIComponent(event.sku), '', event.name, 'EVENT']);
    }
    if (/^[a-z0-9]{1,12}$/.test(query) && /\d/.test(query) &&
        !matches.some((match) => match[1].toLowerCase() === query)) {
      matches.push([teamPath(query.toUpperCase(), seasonId), query.toUpperCase(), 'Look up team number', 'TEAM']);
    }
    if (/^(re|ve)-[a-z0-9-]+$/.test(query) && !matches.length) {
      matches.push(['/event/' + encodeURIComponent(query.toUpperCase()), '', query.toUpperCase(), 'EVENT']);
    }
    ui.suggestions.innerHTML = matches.map(([url, label, name, type]) =>
      '<a href="' + escape(url) + '"><strong>' + escape(label) + '</strong><span>' +
      escape(name) + '</span><small>' + type + '</small></a>').join('');
    if (!matches.length) {
      ui.suggestions.textContent = [high, middle, upcoming].some((result) => result.status === 'rejected')
        ? 'Some results could not load. Search again to retry.' : 'No matching teams or events.';
    }
    if ([high, middle, upcoming].some((result) => result.status === 'rejected')) searchIndex = undefined;
    return matches;
  } catch {
    searchIndex = undefined;
    ui.suggestions.textContent = 'Search is unavailable. Try again.';
    return [];
  }
}

ui.homeQuery.addEventListener('input', () => {
  clearTimeout(homeSearchTimer);
  if (ui.homeQuery.value.trim().length < 2) ui.suggestions.hidden = true;
  else homeSearchTimer = setTimeout(searchHome, 220);
});
ui.homeForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  clearTimeout(homeSearchTimer);
  const matches = await searchHome();
  if (matches.length) location.href = matches[0][0];
});
ui.homeQuery.addEventListener('keydown', (event) => {
  if (event.key === 'ArrowDown') {
    const first = ui.suggestions.querySelector('a');
    if (first) { event.preventDefault(); first.focus(); }
  }
  if (event.key === 'Escape') ui.suggestions.hidden = true;
});

const stages = [
  ['round128', 'Round of 128'], ['round64', 'Round of 64'], ['round32', 'Round of 32'],
  ['round16', 'Round of 16'], ['quarterfinals', 'Quarterfinals'],
  ['semifinals', 'Semifinals'], ['finals', 'Finals'],
];
const percent = (value) => Math.round(100 * value) + '%';
const shown = (number) => number >= 0 ? escape(number) : '—';
const oneDecimal = (value) => Number(value).toFixed(1);

function alliance(match, color) {
  return match.alliances.find((side) => side.color.toLowerCase() === color);
}

function allianceTeams(side, season, focusTeam) {
  return side?.teams.length ? side.teams.map((team) =>
    '<span class="' + (team.id === focusTeam ? 'focus-team' : '') + '">' +
    teamLink(team.number, season) + (side.disqualifiedTeamIds?.includes(team.id) ?
      '<span class="dq-tag" title="Disqualified">DQ</span>' : '') + '</span>').join(' ') : 'TBD';
}

function odds(match) {
  const redCount = alliance(match, 'red')?.teams.length;
  const blueCount = alliance(match, 'blue')?.teams.length;
  if (!redCount || redCount !== blueCount) return '<span class="muted">—</span>';
  const estimate = match.forecast;
  if (!estimate) return '<span class="muted" title="No earlier match data">—</span>';
  const width = (value) => Math.max(0, Math.min(100, 100 * Number(value)));
  const label = percent(estimate.red) + ' red, ' + percent(estimate.blue) + ' blue';
  return '<span class="odds" title="' + escape(label) +
    '"><span class="odds-label"><b class="red">' + percent(estimate.red) + '</b><b class="blue">' +
    percent(estimate.blue) + '</b></span><span class="odds-track" role="img" aria-label="' + escape(label) + '">' +
    '<i style="width:' + width(estimate.red) + '%"></i><i style="width:' + width(estimate.blue) + '%"></i></span></span>';
}

function score(match) {
  if (!match.completed) return '<span class="muted">—</span>';
  const red = alliance(match, 'red')?.score;
  const blue = alliance(match, 'blue')?.score;
  return '<span class="final-score"><span class="' + (red > blue ? 'winner red-winner' : '') + '">' + shown(red) +
    '</span><span class="score-separator">–</span><span class="' + (blue > red ? 'winner blue-winner' : '') + '">' +
    shown(blue) + '</span></span>';
}

function replayButton(match) {
  if (!match.replay) {
    return match.webcast ? '<span class="webcast-fallback" title="Full event webcast">' +
      externalLink(match.webcast, '▶') + '</span>' :
      '';
  }
  return '<button type="button" class="play-match" data-replay="' + escape(match.replay) +
    '" data-match-title="' + escape(match.name) + '" aria-label="Play ' +
    escape(match.name || 'match replay') + '">▶</button>';
}

function matchTable(matches, season, showOdds = true, focusTeam) {
  if (!matches.length) return '<p class="status">No matches have been posted.</p>';
  const phases = [
    ['Qualifications', matches.filter((match) => match.round === 'qualification')],
    ['Playoffs', matches.filter((match) => stages.slice(0, -1).some(([key]) => key === match.round))],
    ['Finals', matches.filter((match) => match.round === 'finals')],
    ['Other matches', matches.filter((match) => ['practice', 'none'].includes(match.round))],
  ];
  return '<div class="match-tables">' + phases.filter(([, rows]) => rows.length).map(([label, rows]) => {
    const columns = [[label], ['Red alliance'], ['Score / time', 'match-score'], ['Blue alliance'], ['Field']];
    if (showOdds) columns.push(['Win probability']);
    return table(columns, rows.map((match) => {
      const red = alliance(match, 'red');
      const blue = alliance(match, 'blue');
      const ownRed = focusTeam && red?.teams.some((team) => team.id === focusTeam);
      const ownBlue = focusTeam && blue?.teams.some((team) => team.id === focusTeam);
      const difference = ownRed ? red.score - blue?.score : blue?.score - red?.score;
      const dq = (ownRed && red.disqualifiedTeamIds?.includes(focusTeam)) ||
        (ownBlue && blue.disqualifiedTeamIds?.includes(focusTeam));
      const outcome = dq ? 'dq' : match.completed && (ownRed || ownBlue) ?
        (difference > 0 ? 'win' : difference < 0 ? 'loss' : 'tie') : '';
      const redWon = match.completed && red?.score > blue?.score;
      const blueWon = match.completed && blue?.score > red?.score;
      return '<tr data-match="' + escape(match.id) + '" class="match-row ' + outcome + '"><td><span class="match-label">' +
        replayButton(match) +
        (outcome ? '<span class="result-dot" aria-label="' + outcome + '" title="' + outcome + '">' + (dq ? 'DQ' : outcome[0].toUpperCase()) + '</span>' : '') +
        escape(match.name || match.round) + '</span></td><td class="red alliance-cell' + (redWon ? ' won-alliance' : '') + '">' +
        allianceTeams(red, season, focusTeam) + '</td><td class="match-score">' + (!match.completed && match.scheduled &&
          Number.isFinite(Date.parse(match.scheduled)) ? '<time datetime="' + escape(match.scheduled) +
          '">' + escape(new Date(match.scheduled).toLocaleTimeString([], {hour:'numeric', minute:'2-digit'})) +
          '</time>' : score(match)) + '</td><td class="blue alliance-cell' + (blueWon ? ' won-alliance' : '') + '">' +
        allianceTeams(blue, season, focusTeam) + '</td><td>' + shown(match.field || null) + '</td>' +
        (showOdds ? '<td class="match-odds">' + odds(match) + '</td>' : '') + '</tr>';
    }));
  }).join('') + '</div>';
}

function bracket(matches, season) {
  const teamKey = (side) => side?.teams.map((team) => team.id).sort((a, b) => a - b).join(',') || '';
  const roundWidth = 254;
  const cardWidth = 215;
  const laneHeight = 91;
  const columns = stages.map(([key, name]) => {
    const pairs = new Map();
    for (const match of matches.filter((row) => row.round === key)) {
      const sides = [teamKey(alliance(match, 'red')), teamKey(alliance(match, 'blue'))];
      const pair = sides.every(Boolean) ? sides.sort().join('|') : 'match-' + match.id;
      if (!pairs.has(pair)) pairs.set(pair, []);
      pairs.get(pair).push(match);
    }
    return {name, series: [...pairs.values()].map((games) => {
      const first = games[0];
      const red = alliance(first, 'red');
      const blue = alliance(first, 'blue');
      const keys = [teamKey(red), teamKey(blue)];
      const wins = [0, 0];
      for (const game of games.filter((row) => row.completed)) {
        const a = alliance(game, 'red');
        const b = alliance(game, 'blue');
        if (a && b && a.score !== b.score) {
          const index = keys.indexOf(teamKey(a.score > b.score ? a : b));
          if (index >= 0) wins[index]++;
        }
      }
      return {games, first, red, blue, keys, wins,
        winner: wins[0] === wins[1] ? null : keys[wins[0] > wins[1] ? 0 : 1]};
    })};
  }).filter((round) => round.series.length);
  if (!columns.length) return '<p class="status">Playoff pairings have not been posted.</p>';

  const connectors = [];
  const lanes = Math.max(...columns.map((round) => round.series.length));
  const height = lanes * laneHeight;
  columns.forEach((round, column) => {
    round.series.forEach((series, index) => {
      const sources = column ? columns[column - 1].series.filter((candidate) =>
        candidate.winner && series.keys.includes(candidate.winner)) : [];
      const spread = height / round.series.length;
      const preferred = sources.length === 2 ? (sources[0].y + sources[1].y) / 2 :
        (index + .5) * spread;
      series.y = Math.max(43, Math.min(height - 43, preferred));
      if (index) series.y = Math.max(series.y, round.series[index - 1].y + 83);
      for (const source of sources) {
        const from = (column - 1) * roundWidth + cardWidth;
        const to = column * roundWidth;
        const middle = (from + to) / 2;
        connectors.push('<path d="M' + from + ' ' + source.y + 'H' + middle +
          'V' + series.y + 'H' + to + '"/>');
      }
    });
  });

  const canvasHeight = Math.max(height, ...columns.flatMap((round) => round.series.map((series) => series.y + 43)));
  const width = (columns.length - 1) * roundWidth + cardWidth;
  return '<div class="bracket-scroll" aria-label="Posted playoff bracket"><div class="bracket-heads" style="width:' +
    width + 'px">' + columns.map((round, index) => '<h3 style="left:' + index * roundWidth +
      'px">' + round.name + '</h3>').join('') + '</div><div class="bracket-tree" style="width:' + width +
    'px;height:' + canvasHeight + 'px"><svg aria-hidden="true" width="' + width + '" height="' + canvasHeight +
    '">' + connectors.join('') + '</svg>' + columns.map((round, index) => round.series.map((series) => {
      const row = (side, color, sideIndex) => {
        const won = series.winner && series.winner === series.keys[sideIndex];
        const scored = series.games.filter((match) => match.completed);
        const points = scored.map((game) => game.alliances.find((candidate) =>
          teamKey(candidate) === series.keys[sideIndex])?.score).filter((value) => value >= 0);
        return '<div class="bracket-side ' + color + (won ? ' won-alliance' : '') + '">' +
          '<span>' + allianceTeams(side, season) + '</span><b>' +
          (points.length ? points.map(shown).join(' · ') : '—') + '</b></div>';
      };
      return '<article class="bracket-node" style="left:' + index * roundWidth + 'px;top:' +
        (series.y - 39) + 'px"><header><span>' + escape(series.first.name || series.first.matchNumber) +
        '</span>' + series.games.map(replayButton).join('') + '</header>' +
        row(series.red, 'red', 0) + row(series.blue, 'blue', 1) + '</article>';
    }).join('')).join('') + '</div></div>';
}
function detailError(message, retry) {
  ui.detail.innerHTML = '<section class="panel"><p class="status" role="status">' +
    escape(message) + (retry ? ' <button type="button">Retry</button>' : '') + '</p></section>';
  if (retry) ui.detail.querySelector('button').addEventListener('click', retry);
}

async function loadDetail(kind, code) {
  const id = ++detailId;
  clearTimeout(eventRefreshTimer);
  teamReplayObserver?.disconnect();
  const params = new URLSearchParams(location.search);
  const season = params.get('season') || ui.season.value;
  detailError(kind === 'event' ? 'Loading event and match results…' : 'Loading team and season results…');
  try {
    if (kind === 'event') {
      const query = {sku: code};
      if (/^\d+$/.test(season)) query.seasonId = season;
      if (params.has('division')) query.division = params.get('division');
      const data = await api('event', query);
      if (id === detailId) {
        let extrasLoaded = false;
        let current = data;
        const update = renderEvent(data, () => loadExtras());
        function loadExtras() {
          if (!current.matches?.length || extrasLoaded) return;
          extrasLoaded = true;
          for (const kind of ['history', 'streams']) {
            api('event', {...query, [kind]: 1}).then((payload) => {
              if (id === detailId) update(kind, payload);
            }).catch(() => {});
          }
        }
        const refresh = async () => {
          if (id !== detailId) return;
          let active = true;
          try {
            if (!document.hidden) {
              const latest = await api('event', query);
              if (id !== detailId) return;
              active = latest.active || latest.partial;
              current = latest;
              update('event', latest);
            }
          } catch {
            // Keep the last usable event visible during an outage.
          }
          if (active && id === detailId) eventRefreshTimer = setTimeout(refresh, 12000);
        };
        if (data.active || data.partial) eventRefreshTimer = setTimeout(refresh, 12000);
      }
    } else {
      await loadTeamDetail(code, season, id);
    }
  } catch (error) {
    if (id === detailId) detailError(error.message, () => loadDetail(kind, code));
  }
}

async function loadTeamDetail(code, season, id) {
  const query = {seasonId: season, number: code};
  const upcomingRequest = api('team', {...query, upcoming: 1}).then(
    data => Array.isArray(data.events) ? data.events : null, () => null);
  let complete = false;
  let identity;
  let skillsRequest;
  let rankingRequest;
  let failed = false;
  const show = (data, partial = false) => {
    if (id !== detailId) return;
    renderTeam(data, season, {partial, failed});
    const schedule = $('teamUpcomingList');
    upcomingRequest.then((events) => {
      if (id !== detailId || !schedule.isConnected) return;
      const combined = new Map((data.events || []).map(event => [event.id, event]));
      for (const event of events || []) combined.set(event.id, event);
      renderTeamUpcoming(schedule, [...combined.values()], events === null);
    });
    const stats = $('officialStats');
    rankingRequest ||= api('openskill', {seasonId:season, gradeLevel:'All'}).catch(() => null);
    rankingRequest.then((leaderboard) => {
      if (id !== detailId || !stats.isConnected) return;
      const row = leaderboard?.rows.find((item) => item.teamNumber === data.team.number);
      if (!row) return;
      const ranks = row.componentRanks || {};
      stats.insertAdjacentHTML('beforeend', [
        ['Solar rank', row.rank], ['OpenSkill rank', ranks.openskill],
        ['Teamwork rank', ranks.teamwork], ['Programming rank', ranks.programming],
        ['Overall Skills rank', ranks.skills], ['Awards rank', ranks.awards],
      ].filter(([, rank]) => rank).map(([label, rank]) => metric(label, '#' + rank)).join(''));
    });
    const grade = data.team.grade?.toLowerCase().includes('middle') ? 'Middle School' : 'High School';
    skillsRequest ||= api('skills', {seasonId: season, gradeLevel: grade}).catch(() => []);
    skillsRequest.then((rankings) => {
      if (id !== detailId || !stats.isConnected) return;
      const skills = rankings.find((row) => row.teamId === data.team.id);
      if (skills) stats.insertAdjacentHTML('beforeend',
        metric('World Skills', skills.combinedScore) + metric('Skills rank', '#' + skills.rank));
    });
  };
  let summaryRequest;
  const loadSummary = () => {
    if (complete || id !== detailId) return;
    summaryRequest ||= api('team', {...query, summary: 1}).then((data) => {
      if (!complete && data.team) {
        identity = data;
        show(data, true);
      }
    }).catch(() => {});
    return summaryRequest;
  };
  void loadSummary();
  try {
    const data = await api('team', query);
    complete = true;
    if (id !== detailId) return;
    if (!data.team) return detailError('Team not found.');
    show(data, data.partial === true);
    let lastVersion = data._cachedAt;
    const refresh = async () => {
      if (id !== detailId) return;
      try {
        if (!document.hidden) {
          const latest = await api('team', query);
          if (id !== detailId) return;
          if (latest._cachedAt !== lastVersion) {
            lastVersion = latest._cachedAt;
            if (latest.team) show(latest);
          }
          if (!latest.active) return;
        }
      } catch {}
      if (id === detailId) eventRefreshTimer = setTimeout(refresh, 12000);
    };
    if (data.active) eventRefreshTimer = setTimeout(refresh, 12000);
  } catch (error) {
    failed = true;
    if (identity) show(identity, true);
    else {
      await loadSummary();
      if (!identity) throw error;
    }
  }
}

function renderEvent(data, loadExtras) {
  const {event, division} = data;
  let {standings = [], matches = []} = data;
  let forecasts = {};
  let replays = {};
  let information;
  let informationPending = false;
  let infoSelection = 0;
  let roster;
  let rosterError = false;
  let rosterLoading = false;
  let rosterOrder = 'number';
  let seasonRatings;
  const upcoming = Boolean(event.start && new Date(event.start) > new Date());
  const sections = [
    ...(upcoming ? [['roster', 'Teams']] : []),
    ['standings', 'Standings'], ['matches', 'Matches'],
    ...(!upcoming ? [['roster', 'Teams']] : []),
    ['bracket', 'Alliance bracket'], ['information', 'Information'],
  ];
  let section = sections[0][0];
  document.title = event.name + ' · Solar';
  const divPicker = event.divisions.length > 1 ? '<label>Division <select id="division">' +
    event.divisions.map((item) => '<option value="' + escape(item.id) + '"' +
      (item.id === division?.id ? ' selected' : '') + '>' + escape(item.name) + '</option>').join('') +
    '</select></label>' : '';
  ui.detail.innerHTML = '<div class="detail-intro"><a href="/#events">← Events</a><h1>' + escape(event.name) + '</h1><p>' +
    escape([dateRange(event), locationText(event.location)].filter(Boolean).join(' · ')) + '</p></div>' +
    '<div class="detail-toolbar event-toolbar"><div class="detail-tabs" role="group" aria-label="Event sections">' +
    '<span class="nav-indicator" aria-hidden="true"></span>' +
    sections.map(([key, label]) => '<button type="button" data-section="' + key + '" aria-pressed="' +
      (key === section) + '">' + label + '</button>').join('') + '</div>' +
    '<div class="event-tools">' + divPicker +
    '<button type="button" class="metrics-help" id="showMetrics" aria-haspopup="dialog" aria-label="Explain standings metrics">?</button></div>' +
    '</div><div id="eventContent"></div>';
  const decimalCell = (value) => '<td class="numeric">' + (Number.isFinite(value) ? oneDecimal(value) : '—') + '</td>';
  const standingsTable = () => standings.length ? (data.standingsSource === 'previous'
    ? '<p class="status" role="status">Showing the last posted standings while RobotEvents updates them.</p>' : '') + table(
    [['Rank'], ['Team'], ['W–L–T'], ['WP', 'numeric'], ['AP', 'numeric'], ['SP', 'numeric'],
      ['OpenSkill', 'numeric'], ['Rated', 'numeric'], ['OPR', 'numeric'], ['DPR', 'numeric'], ['CCWM', 'numeric']],
    standings.map((row) => '<tr data-team-report="' + escape(row.team.id) + '"><td>' + shown(row.rank) + '</td><td>' +
      '<button type="button" class="scout-report-link" data-report-team="' + escape(row.team.id) +
      '">' + escape(row.team.number) + '</button></td><td>' +
      [row.wins, row.losses, row.ties].map(shown).join('–') +
      '</td><td class="numeric">' + shown(row.wp) + '</td><td class="numeric">' + shown(row.ap) +
      '</td><td class="numeric">' + shown(row.sp) + '</td><td class="numeric">' +
      (row.skill?.matches ? '<span class="score">' + oneDecimal(row.skill.rating) + '</span>' : '—') +
      '</td><td class="numeric">' + (row.skill?.matches || '—') + '</td>' +
      decimalCell(row.opr) + decimalCell(row.dpr) + decimalCell(row.ccwm) + '</tr>')
  )
    : '<p class="status">' + (data.standingsSource === 'missing'
      ? 'Matches have been scored but RobotEvents hasn’t posted standings yet. Solar checks again every minute.'
      : 'Standings have not been posted.') + '</p>';
  const content = $('eventContent');
  const tabs = ui.detail.querySelector('.detail-tabs');
  disconnectEventIndicator?.();
  const indicator = wireSlidingIndicator(tabs, 'button', '[aria-pressed="true"]');
  disconnectEventIndicator = indicator.disconnect;
  const renderRoster = () => {
    const ratings = new Map(standings.filter((row) => row.skill?.matches).map((row) => [row.team.number, row.skill.rating]));
    const rating = (team) => ratings.get(team.number) ?? seasonRatings?.get(team.number);
    const alphabetical = (a, b) => a.number.localeCompare(b.number, undefined, {numeric:true});
    const sorted = [...(roster || [])].sort((a,b) => (rosterOrder === 'rating'
      ? (rating(b) ?? -Infinity) - (rating(a) ?? -Infinity) : 0) || alphabetical(a,b));
    return roster?.length ? '<div class="event-webcasts"><label>Sort <select id="rosterOrder">' +
      '<option value="number">Team number (A–Z)</option><option value="rating"' +
      (rosterOrder === 'rating' ? ' selected' : '') + '>OpenSkill</option></select></label></div>' + table(
    [['Team'], ['Name'], ['Organization'], ['Location'], ['OpenSkill', 'numeric']],
    sorted.map((team) => '<tr data-row-link><td>' + teamLink(team.number, event.seasonId) + '</td><td>' +
      escape(team.teamName) + '</td><td>' + escape(team.organization) + '</td><td>' +
      escape(locationText(team.location)) + '</td>' + decimalCell(rating(team)) + '</tr>'),
  ) : '<p class="status" role="status">' + (rosterError
    ? 'Could not load the team list. <button type="button" id="retryRoster">Retry</button>'
    : roster ? 'No registered teams have been posted.' : 'Loading registered teams…') + '</p>';
  };
  const renderSection = (animate = false) => {
    const webcastLinks = section === 'matches' ? eventWebcastLinks(event, information) : [];
    const matchRows = section === 'matches' && information?.webcasts?.length ?
      matches.map((match) => ({...match, webcast: match.completed ? information.webcasts[0] : null})) : matches;
    const html = section === 'information' ? eventInformation(event, information, informationPending, infoSelection) :
      section === 'roster' ? renderRoster() :
      section === 'standings' ? standingsTable() :
      section === 'matches' ? (webcastLinks.length ?
        '<div class="event-webcasts">' + webcastLinks.join(' · ') + '</div>' : '') +
        matchTable(matchRows, event.seasonId) : bracket(matches, event.seasonId);
    content.innerHTML = '<div class="' + (section === 'information' ? '' : 'panel ') +
      (animate ? 'event-section-enter' : '') + '">' +
      (data.partial && ['standings', 'matches', 'bracket'].includes(section) ?
        '<p class="status" role="status">Showing saved results while full event data loads.</p>' : '') + html + '</div>';
  };
  const loadRoster = () => {
    if (rosterLoading || roster) return;
    rosterLoading = true;
    rosterError = false;
    api('event', {sku: event.sku, roster: 1}).then((teams) => { roster = teams; })
      .catch(() => { rosterError = true; }).finally(() => {
        rosterLoading = false;
        if (content.isConnected && section === 'roster') renderSection();
      });
  };
  content.addEventListener('change', (change) => {
    if (change.target.id !== 'rosterOrder') return;
    rosterOrder = change.target.value;
    renderSection();
    $('rosterOrder')?.focus();
    if (rosterOrder !== 'rating' || seasonRatings || !event.seasonId) return;
    api('openskill', {seasonId:event.seasonId, gradeLevel:'All'}).then(({rows}) => {
      seasonRatings = new Map(rows.filter((row) => Number.isFinite(row.skill?.rating))
        .map((row) => [row.teamNumber, row.skill.rating]));
      if (content.isConnected && section === 'roster') renderSection();
    }).catch(() => {});
  });
  content.addEventListener('click', (event) => {
    const item = event.target.closest('[data-info-section]');
    if (item) {
      infoSelection = Number(item.dataset.infoSection);
      renderSection();
      content.querySelector('[aria-current="true"]')?.focus({preventScroll:true});
    } else if (event.target.id === 'retryRoster') {
      loadRoster();
      renderSection();
    } else if (!event.target.closest('a, input, select') || event.target.closest('[data-report-team]')) {
      const row = event.target.closest('[data-team-report]');
      const team = standings.find((entry) => String(entry.team.id) === row?.dataset.teamReport)?.team;
      if (team) openTeamEvent(team, data.event, data.event.seasonId, matches.filter((match) =>
        match.alliances.some((side) => side.teams.some((member) => member.id === team.id))), division?.id);
    }
  });
  $('showMetrics').addEventListener('click', () => $('metricsDialog').showModal());
  renderSection();
  if (upcoming) loadRoster();
  tabs.querySelectorAll('[data-section]').forEach((button) => {
    button.addEventListener('click', () => {
      if (section === button.dataset.section) return;
      tabs.querySelectorAll('[data-section]').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
      section = button.dataset.section;
      if (section === 'roster') loadRoster();
      if (section === 'matches' || section === 'bracket') loadExtras?.();
      indicator.sync();
      if (['information', 'matches'].includes(section) && !information && !informationPending) {
        informationPending = true;
        api('event', {sku: event.sku, information: 1}).then((result) => {
          information = result;
        }).catch(() => {}).finally(() => {
          informationPending = false;
          if (['information', 'matches'].includes(section) && content.isConnected) renderSection();
        });
      }
      renderSection(true);
    });
  });
  $('division')?.addEventListener('change', (change) => {
    const url = new URL(location.href);
    url.searchParams.set('division', change.target.value);
    history.replaceState(null, '', url);
    loadDetail('event', event.sku);
  });
  return (kind, payload) => {
    if (kind === 'event') {
      if (data._cachedAt && data._cachedAt === payload._cachedAt) return;
      data = payload;
      standings = payload.standings || [];
      matches = payload.matches || [];
    } else if (kind === 'history') forecasts = payload;
    else replays = payload;
    for (const match of matches) {
      if (Object.hasOwn(forecasts, match.id)) match.forecast = forecasts[match.id];
      match.replay = replays[match.id];
    }
    if (section !== 'information' && section !== 'roster' &&
        (kind === 'event' || section !== 'standings')) renderSection();
  };
}

function externalLink(value, label) {
  try {
    const url = new URL(value);
    if (['http:', 'https:'].includes(url.protocol) && !url.username && !url.password) {
      return '<a href="' + escape(url.href) + '" target="_blank" rel="noopener noreferrer">' + escape(label) + ' ↗</a>';
    }
  } catch {
    // Invalid or missing source links are omitted.
  }
  return '';
}

function eventInformation(event, information, loading, selected) {
  const official = 'https://events.vex.com/robot-competitions/vex-robotics-competition/' +
    encodeURIComponent(event.sku) + '.html';
  const venue = [event.location?.venue, event.location?.address1, locationText(event.location)].filter(Boolean);
  const sections = information?.sections || [];
  const webcasts = eventWebcastLinks(event, information);
  const items = [{name:'Information', html:'<header><h2>Event details</h2>' +
    externalLink(official, 'Official event page') + '</header><p>' +
    escape([dateRange(event), ...venue].join(' · ')) + '</p>' +
    (loading ? '<p role="status">Loading organizer information…</p>' : '') +
    (!loading && !sections.length ? '<p class="muted">Open the official event page for the organizer’s agenda and updates.</p>' : '')}];
  for (const {title, text, links} of sections) {
    const html = (text ? '<p class="event-info-copy">' + escape(text) + '</p>' : '') +
      (links || []).map(({url, label}) => externalLink(url, label)).filter(Boolean).join(' · ');
    if (title === 'General information') items[0].html += '<h2>General information</h2>' + html;
    else items.push({name:title, html:'<h2>' + escape(title) + '</h2>' + html});
  }
  if (!loading && !sections.some(({title}) => title === 'Agenda')) {
    items.push({name:'Agenda', html:'<h2>Agenda</h2><p class="muted">Check the organizer’s event page for the latest agenda.</p>' +
      externalLink(official + '#agenda', 'Open official agenda')});
  }
  if (webcasts.length && !sections.some(({title}) => title === 'Webcast')) {
    items.push({name:'Webcast', html:'<h2>Webcast</h2>' + webcasts.join(' · ')});
  }
  const index = selected < items.length ? selected : 0;
  return '<div class="split-layout info-layout"><aside class="jump-list info-nav" aria-label="Event information sections"><div>' +
    items.map(({name}, i) => '<button type="button" data-info-section="' + i + '"' +
      (i === index ? ' aria-current="true"' : '') + '>' + escape(name) + '</button>').join('') +
    '</div></aside><section class="panel event-information">' + items[index].html + '</section></div>';
}

function eventWebcastLinks(event, information) {
  const links = [...new Set([...(information?.webcasts || []), event.livestreamLink].filter(Boolean))];
  return links.map((url, index) =>
    externalLink(url, links.length > 1 ? 'Event webcast ' + (index + 1) : 'Event webcast')).filter(Boolean);
}

function dateLabel(date) {
  return date ? new Date(date).toLocaleDateString(undefined, {month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC'}) : '';
}

function dateRange(event) {
  const start = new Date(event.start);
  const end = new Date(event.end);
  if (!event.start || Number.isNaN(start.valueOf())) return 'Date TBD';
  if (!event.end || Number.isNaN(end.valueOf()) || end < start) return dateLabel(event.start);
  return new Intl.DateTimeFormat(undefined, {
    month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC',
  }).formatRange(start, end);
}

function metric(label, value) {
  return '<span><small>' + label + '</small><b>' + escape(value) + '</b></span>';
}

const insightColumns = [
  ['score', 'Solar score'], ['rating', 'OpenSkill'], ['winRate', 'Win %'],
  ['averagePoints', 'Avg points'], ['averageConceded', 'Avg conceded'],
  ['opr', 'OPR'], ['dpr', 'DPR'], ['ccwm', 'CCWM'], ['matches', 'Rated matches'],
  ['eventsPlayed', 'Events'], ['combinedScore', 'Skills'], ['driverScore', 'Driving'],
  ['programmingScore', 'Programming'], ['awardCount', 'Awards'],
];

function insightValue(row, key) {
  if (key === 'rating') return row.skill?.rating;
  if (key === 'matches') return row.skill?.matches;
  if (key === 'winRate') return row.skill?.matches ? 100 * row.skill.wins / row.skill.matches : null;
  return Number.isFinite(row[key]) ? row[key] : null;
}

function comparisonBars(title, entries) {
  const values = entries.filter(({value}) => Number.isFinite(value));
  if (!values.length) return '';
  const max = Math.max(1, ...values.map(({value}) => Math.abs(value)));
  return '<section class="scout-chart"><h3>' + escape(title) + '</h3>' +
    values.map(({label, value}) => '<div class="scout-bar"><span>' + escape(label) +
      '</span><span class="scout-track"><i class="' + (value < 0 ? 'negative' : '') +
      '" style="width:' + 100 * Math.abs(value) / max + '%"></i></span><b>' +
      oneDecimal(value) + '</b></div>').join('') + '</section>';
}

function renderInsights(visible, filtered) {
  const label = insightColumns.find(([key]) => key === insightMetric)[1];
  const value = (row, key) => {
    const number = insightValue(row, key);
    if (!Number.isFinite(number)) return '—';
    return ['score', 'rating', 'averagePoints', 'averageConceded', 'opr', 'dpr', 'ccwm'].includes(key) ?
      oneDecimal(number) : shown(Math.round(number)) + (key === 'winRate' ? '%' : '');
  };
  const compared = rows.filter((row) => comparedTeams.has(row.teamNumber));
  ui.results.innerHTML = '<div class="insights-top"><div><h2>Season scouting</h2><p>Select up to four teams to compare. Points are alliance averages; OPR, DPR and CCWM average available division estimates.</p>' +
    '<details><summary>How Solar ranks teams</summary><p>Solar score starts with event-weighted OpenSkill and adds teamwork, autonomous match points, separate driving and programming Skills results, and awards where available. Results across more events carry more evidence.</p></details></div>' +
    '<label>Sort by <select id="insightMetric">' +
    insightColumns.map(([key, name]) => '<option value="' + key + '"' +
      (key === insightMetric ? ' selected' : '') + '>' + name + '</option>').join('') +
    '</select></label></div>' +
    comparisonBars(label + (compared.length ? ' · selected teams' : ' · top six in this view'), (compared.length ? compared : filtered.slice(0, 6)).map((row) =>
      ({label: row.teamNumber, value: insightValue(row, insightMetric)}))) +
    table([['Compare'], ['Rank'], ['Team'], ['Record'], ...insightColumns.map(([, name]) => [name, 'numeric'])],
      visible.map((row) => '<tr data-row-link><td><input type="checkbox" data-compare="' + escape(row.teamNumber) +
        '" aria-label="Compare ' + escape(row.teamNumber) + '"' + (comparedTeams.has(row.teamNumber) ? ' checked' :
          compared.length >= 4 ? ' disabled' : '') + '></td><td>' + shown(row.rank) + '</td><td>' +
        teamLink(row.teamNumber, ui.season.value) + '<small class="insight-team-name">' +
        escape(row.teamName || row.organization) + '</small></td><td>' +
        [row.skill?.wins, row.skill?.losses, row.skill?.draws].map(shown).join('–') +
        '</td>' + insightColumns.map(([key]) => '<td class="numeric">' + value(row, key) + '</td>').join('') + '</tr>'));
  $('insightMetric').onchange = (event) => {
    insightMetric = event.target.value;
    page = 0;
    render();
    $('insightMetric')?.focus();
  };
  for (const checkbox of ui.results.querySelectorAll('[data-compare]')) checkbox.onchange = () => {
    const number = checkbox.dataset.compare;
    if (checkbox.checked) comparedTeams.add(number);
    else comparedTeams.delete(number);
    render();
    [...ui.results.querySelectorAll('[data-compare]')].find((item) => item.dataset.compare === number)?.focus();
  };
}

let reportRequest = 0;
$('closeTeamEvent').onclick = () => $('teamEventDialog').close();

function openTeamEvent(team, event, season, initialMatches = [], divisionId) {
  const token = ++reportRequest;
  const dialog = $('teamEventDialog');
  const output = $('teamEventReport');
  let divisionRows = [];
  let supplements;
  let supplementaryFailed = false;
  let detailPending = true;
  $('teamEventTitle').textContent = team.number + ' · ' + (event.name || event.sku);
  if (!dialog.open) dialog.showModal();
  const redraw = () => {
    if (token !== reportRequest || !dialog.open) return;
    const own = (match) => match.alliances.find((side) => side.teams.some((member) => member.id === team.id));
    const published = divisionRows.flatMap((division) => division.matches || []).filter(own);
    const matches = [...new Map([...initialMatches, ...published].map((match) => [match.id, match])).values()];
    const scored = matches.filter((match) => match.completed && own(match));
    const scores = scored.map((match) => ({label: match.name || 'Match', value: own(match).score}));
    const opponents = scored.map((match) => match.alliances.find((side) => side !== own(match))?.score)
      .filter(Number.isFinite);
    const average = (values) => values.length ? oneDecimal(values.reduce((sum, n) => sum + n, 0) / values.length) : '—';
    const tiles = [];
    for (const division of divisionRows) {
      const row = division.standings?.find((entry) => entry.team.id === team.id);
      if (!row) continue;
      tiles.push('<h3>' + escape(division.division?.name || 'Division standings') + '</h3><div class="stats">' +
        [['Rank', row.rank], ['Wins', row.wins], ['Losses', row.losses], ['Ties', row.ties],
          ['WP', row.wp], ['AP', row.ap], ['Strength points (SP)', row.sp],
          ['AWP', row.awp], ['OPR', row.opr], ['DPR', row.dpr], ['CCWM', row.ccwm],
          ['Event OpenSkill', row.skill?.rating], ['High score', row.highScore]].map(([label, value]) =>
          metric(label, Number.isFinite(value) && value !== -1 ? oneDecimal(value) : '—')).join('') + '</div>');
    }
    const skills = supplements?.skills?.filter((row) => row.team.id === team.id) || [];
    const awards = supplements?.awards?.filter((row) =>
      row.recipients?.some((name) => String(name).toUpperCase() === team.number.toUpperCase())) || [];
    output.innerHTML = '<p class="scout-links">' + teamLink(team.number, season) + ' · ' +
      eventLink(event.sku, 'Open event') + '</p><div class="stats">' +
      metric('Scored matches', scores.length) + metric('Avg alliance points', average(scores.map((entry) => entry.value))) +
      metric('Avg opponent points', average(opponents)) + '</div>' + tiles.join('') +
      (detailPending ? '<p role="status">Loading official event statistics…</p>' : !tiles.length ?
        '<p>Official team standings are unavailable.</p>' : '') +
      '<h3>Robot Skills and awards</h3>' +
      (supplements ? '<div class="stats">' + (skills.length ? skills.map((row) =>
        metric((row.type || 'Skills') + ' skills', shown(row.score) + ' · rank ' + shown(row.rank))).join('') :
        metric('Skills', 'No posted results')) + metric('Awards', awards.length) + '</div>' +
        (awards.length ? '<ul>' + awards.map((row) => '<li>' + escape(row.title) + '</li>').join('') + '</ul>' : '') :
        '<p role="status">' + (supplementaryFailed ? 'Skills and awards are unavailable.' : 'Loading Skills and awards…') + '</p>') +
      comparisonBars('Alliance points by match', scores) + '<h3>Match results and predictions</h3>' +
      matchTable(matches, season, true, team.id);
  };
  redraw();
  const divisions = [...new Set(initialMatches.map((match) => match.division.id))];
  if (divisionId != null && !divisions.includes(divisionId)) divisions.push(divisionId);
  Promise.allSettled((divisions.length ? divisions : [undefined]).map((division) =>
    api('event', {sku:event.sku, ...(division == null ? {} : {division})}))).then((results) => {
    divisionRows = results.filter((result) => result.status === 'fulfilled').map((result) => result.value);
    detailPending = false;
    redraw();
  });
  api('event', {sku:event.sku, scouting:1}).then((data) => { supplements = data; })
    .catch(() => { supplementaryFailed = true; }).finally(redraw);
}

function populateTeamSeasons(picker, season) {
  if (!picker || !season) return;
  const choices = seasonsReady ? [...ui.season.options].map((option) => new Option(option.textContent, option.value)) : [];
  if (!choices.some((option) => option.value === String(season))) choices.unshift(new Option('Selected season', season));
  picker.replaceChildren(...choices);
  picker.value = season;
  picker.disabled = !seasonsReady;
}

function renderTeam(data, season, {partial = false, failed = false} = {}) {
  teamReplayObserver?.disconnect();
  const {team, events = [], skill, matches = []} = data;
  const stat = metric;
  document.title = team.number + ' · ' + team.teamName + ' · Solar';
  const ratings = skill?.matches
    ? stat('OpenSkill', oneDecimal(skill.rating)) + stat('Skill mean', oneDecimal(skill.mean)) +
      stat('Uncertainty', '±' + oneDecimal(skill.uncertainty)) +
      stat('Record', [skill.wins, skill.losses, skill.draws].join('–')) + stat('Rated matches', skill.matches)
    : partial ? '' : stat('OpenSkill', 'Unrated');
  const byEvent = new Map();
  for (const match of matches) {
    if (!byEvent.has(match.event.id)) byEvent.set(match.event.id, []);
    byEvent.get(match.event.id).push(match);
  }
  const allEvents = new Map(events.map((event) => [event.id, event]));
  for (const [id, played] of byEvent) {
    if (!allEvents.has(id)) allEvents.set(id, played[0].event);
  }
  const eventRows = [...allEvents.values()]
    .filter(event => !(Date.parse(event.start) > Date.now()) || byEvent.get(event.id)?.length)
    .sort((a, b) => (a.start || '9999').localeCompare(b.start || '9999'));
  const eventCards = eventRows.map((event) => {
    const played = byEvent.get(event.id) || [];
    const caption = dateRange(event);
    const place = locationText(event.location);
    return {
      id: 'team-event-' + Number(event.id),
      sku: event.sku,
      played,
      name: event.name || event.sku,
      caption,
      html: '<div class="section-heading team-event-heading"><div><h2><button type="button" class="scout-report-link" data-event-report="' +
        escape(event.id) + '">' + escape(event.name || event.sku) + '</button></h2><p>' +
        escape([caption, place].filter(Boolean).join(' · ')) + '</p></div>' +
        '<span class="scout-report-arrow" aria-hidden="true">↗</span></div>' +
        matchTable(played, season, true, team.id),
    };
  });
  ui.detail.innerHTML = '<div class="detail-intro"><a href="/#teams">← Teams</a><p class="eyebrow">TEAM ' +
    escape(team.number) + '</p><h1>' + escape(team.teamName || team.number) + '</h1><p>' +
    escape([team.organization, locationText(team.location)].filter(Boolean).join(' · ')) + '</p></div>' +
    '<section class="panel"><div class="detail-toolbar"><h2>Season overview</h2><label>Season <select id="teamSeason"></select>' +
    '</label></div><div class="stats" id="officialStats">' + ratings +
    '</div><p class="status">' + (partial ? 'Showing available matches while the full profile loads. ' +
      '<button type="button" data-retry-team>Refresh results</button>' : 'Open a season event for its scouting report.') + '</p></section>' +
    '<section class="panel upcoming-panel"><div class="detail-toolbar"><h2>Upcoming competitions</h2></div>' +
    '<div id="teamUpcomingList" aria-live="polite"></div></section>' +
    (eventCards.length ? '<div class="split-layout">' + jumpList('Season events', eventCards) +
      '<div class="split-content">' + eventCards.map((event) =>
        '<section class="panel team-event-card" tabindex="-1" id="' + event.id + '">' +
        event.html + '</section>').join('') + '</div></div>' :
      '<section class="panel"><p class="status" role="status">' + (failed ?
        'Season results are temporarily unavailable. <button type="button" id="retryTeamResults">Retry</button>' :
        partial ? 'Loading season matches…' : 'No match history for this season yet.') + '</p></section>');
  renderTeamUpcoming($('teamUpcomingList'), events, false, true);
  populateTeamSeasons($('teamSeason'), season);
  $('retryTeamResults')?.addEventListener('click', () => loadDetail('team', team.number));
  ui.detail.querySelector('[data-retry-team]')?.addEventListener('click', () => loadDetail('team', team.number));
  wireJumps(ui.detail);
  for (const event of eventRows) {
    const card = $('team-event-' + Number(event.id));
    card?.addEventListener('click', (click) => {
      if (click.target.closest('a, button:not([data-event-report]), input, select') ||
          window.getSelection()?.toString()) return;
      openTeamEvent(team, event, season, byEvent.get(event.id) || []);
    });
  }
  const requestId = detailId;
  teamReplayObserver = new IntersectionObserver((entries, observer) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      observer.unobserve(entry.target);
      const card = eventCards.find((event) => event.id === entry.target.id);
      const divisions = [...new Set(card.played.map((match) => match.division.id))];
      const findRow = (match) => entry.target.querySelector('tr[data-match="' + Number(match.id) + '"]');
      const addVideos = () => {
        for (const match of card.played) {
          const label = findRow(match)?.querySelector('.match-label');
          if (!label) continue;
          label.querySelector('.play-match,.webcast-fallback')?.remove();
          label.insertAdjacentHTML('afterbegin', replayButton(match));
        }
      };
      api('event', {sku: card.sku, information: 1}).then(({webcasts}) => {
        if (requestId !== detailId || !webcasts?.length) return;
        card.played.filter((match) => match.completed).forEach((match) => { match.webcast = webcasts[0]; });
        addVideos();
      }).catch(() => {});
      for (const division of divisions) {
        const query = {sku: card.sku, division};
        api('event', {...query, streams: 1}).then((replays) => {
          if (requestId !== detailId) return;
          for (const match of card.played) {
            if (replays[match.id]) match.replay = replays[match.id];
          }
          addVideos();
        }).catch(() => {});
      }
    }
  }, {rootMargin: '120px'});
  for (const card of eventCards) {
    if (card.sku && card.played.length) teamReplayObserver.observe($(card.id));
  }
  $('teamSeason').addEventListener('change', (event) => {
    const selected = event.target.value;
    history.replaceState(null, '', teamPath(team.number, selected));
    loadDetail('team', team.number);
  });
}

function renderTeamUpcoming(container, events, failed, loading = false) {
  const now = Date.now();
  const upcoming = events.filter(event => event.sku && Date.parse(event.start) > now)
    .sort((a, b) => Date.parse(a.start) - Date.parse(b.start));
  if (upcoming.length) {
    container.innerHTML = '<ul class="upcoming-list">' + upcoming.map(event =>
      '<li><a href="/event/' + encodeURIComponent(event.sku) + '"><span><strong>' + escape(event.name || event.sku) +
      '</strong><small>' + escape([dateRange(event), locationText(event.location)].filter(Boolean).join(' · ')) +
      '</small></span><span aria-hidden="true">↗</span></a></li>').join('') + '</ul>';
  } else {
    container.innerHTML = '<p class="status">' + (loading ? 'Checking registrations…' :
      failed ? 'Upcoming registrations are temporarily unavailable.' : 'No upcoming competitions listed for this season.') + '</p>';
  }
}

const topNav = document.querySelector('.top-nav');
const replayDialog = $('replayDialog');
let replayFrame = $('replayPlayer');
let replayUrl;
let replayController;
let replaySession = 0;
let replayReadyTimer;
const replayLibraries = {};
const blockedYouTubeVideos = new Map();
$('closeMetrics').addEventListener('click', () => $('metricsDialog').close());

function replayMessage(text, hidePlayer = false) {
  $('replayStatus').textContent = text;
  $('replayStatus').hidden = !text;
  replayFrame.hidden = hidePlayer;
}

function isYouTubeReplay() {
  return replayUrl?.hostname === 'www.youtube.com';
}

function replayPosition() {
  const value = isYouTubeReplay() ? replayUrl.searchParams.get('start') : replayUrl.hash.match(/^#t=(\d+)s$/)?.[1];
  return Number(value) || 0;
}

function updateReplayLink(seconds) {
  const youtube = isYouTubeReplay();
  if (youtube) replayUrl.searchParams.set('start', seconds);
  else replayUrl.hash = 't=' + seconds + 's';
  $('replayExternal').href = youtube ? 'https://www.youtube.com/watch?' +
    new URLSearchParams({v:replayUrl.pathname.split('/').pop(), t:String(seconds)}) : replayUrl.href;
  $('replayExternal').textContent = youtube ? 'Watch on YouTube ↗' : 'Open Vimeo player ↗';
}

function loadReplayLibrary(provider) {
  if (provider === 'youtube' && window.YT?.Player) return Promise.resolve();
  if (provider === 'vimeo' && window.Vimeo?.Player) return Promise.resolve();
  replayLibraries[provider] ||= new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = provider === 'youtube' ? 'https://www.youtube.com/iframe_api' : 'https://player.vimeo.com/api/player.js';
    if (provider === 'youtube') window.onYouTubeIframeAPIReady = resolve;
    else script.onload = resolve;
    script.onerror = () => {
      delete replayLibraries[provider];
      script.remove();
      reject(Error('Player controls unavailable'));
    };
    document.head.append(script);
  });
  return replayLibraries[provider];
}

async function attachReplayControls(session) {
  const youtube = isYouTubeReplay();
  await loadReplayLibrary(youtube ? 'youtube' : 'vimeo');
  if (session !== replaySession) return;
  if (youtube) {
    const player = new YT.Player(replayFrame, {events: {
      onReady: ({target}) => {
        if (session !== replaySession) return;
        clearTimeout(replayReadyTimer);
        replayController = {
          time: () => target.getCurrentTime(),
          seek: (seconds) => target.seekTo(seconds, true),
          speed: (rate) => {
            if (!target.getAvailablePlaybackRates().includes(rate)) throw Error('Speed unavailable');
            target.setPlaybackRate(rate);
          },
        };
        applyReplaySpeed();
      },
      onError: ({data}) => {
        if (session !== replaySession) return;
        if ([101,150].includes(data)) blockedYouTubeVideos.set(replayUrl.pathname, data);
        showYouTubeFallback(data);
      },
    }});
    // Keep the SDK bound to the existing frame while the dialog is open.
    replayFrame.replayInstance = player;
  } else {
    const player = new Vimeo.Player(replayFrame);
    replayFrame.replayInstance = player;
    await player.ready();
    if (session !== replaySession) return;
    clearTimeout(replayReadyTimer);
    replayController = {
      time: () => player.getCurrentTime(),
      seek: (seconds) => player.setCurrentTime(seconds),
      speed: (rate) => player.setPlaybackRate(rate),
    };
    if ($('replaySpeed').value !== '1') applyReplaySpeed();
  }
}

function showYouTubeFallback(code) {
  clearTimeout(replayReadyTimer);
  replayController = undefined;
  $('replayStatus').dataset.providerError = code;
  $('replaySpeed').disabled = true;
  replayMessage([101,150].includes(code)
    ? 'YouTube blocks this recording from playing on other sites. Watch on YouTube to start at this timestamp.'
    : 'YouTube couldn’t play this recording here. Watch on YouTube to start at this timestamp.', true);
}

async function applyReplaySpeed() {
  if (!replayController) return;
  const session = replaySession;
  try {
    await replayController.speed(Number($('replaySpeed').value));
    if (session === replaySession && !replayFrame.hidden) replayMessage('');
  } catch {
    if (session !== replaySession) return;
    $('replaySpeed').value = '1';
    replayMessage('This recording doesn’t offer the selected speed.', replayFrame.hidden);
  }
}

async function shiftReplay(direction) {
  if (!replayUrl || !$('replayStep').reportValidity()) return;
  const session = replaySession;
  const offset = direction * Number($('replayStep').value);
  const controller = replayController;
  let current = replayPosition();
  if (controller) {
    try {
      const playing = await controller.time();
      if (Number.isFinite(playing)) current = playing;
    } catch {}
  }
  if (session !== replaySession) return;
  const seconds = Math.max(0, Math.round(current + offset));
  updateReplayLink(seconds);
  if (controller) {
    try {
      await controller.seek(seconds);
      return;
    } catch {}
  }
  if (session === replaySession && !replayFrame.hidden) replayFrame.src = replayUrl.href;
}

$('replayEarlier').addEventListener('click', () => shiftReplay(-1));
$('replayLater').addEventListener('click', () => shiftReplay(1));
$('replaySpeed').addEventListener('change', applyReplaySpeed);
document.addEventListener('click', (event) => {
  const row = event.target.closest('[data-row-link]');
  if (row && !event.target.closest('a, button, input, select') && !window.getSelection()?.toString()) {
    const link = row.querySelector('a');
    if (link && !event.ctrlKey && !event.metaKey && !event.shiftKey && !event.altKey) link.click();
  }
  const button = event.target.closest('[data-replay]');
  if (!button) return;
  const url = new URL(button.dataset.replay);
  if (url.protocol !== 'https:' || !['player.vimeo.com', 'www.youtube-nocookie.com', 'www.youtube.com'].includes(url.hostname)) return;
  if (url.hostname !== 'player.vimeo.com') {
    url.hostname = 'www.youtube.com';
    url.searchParams.set('enablejsapi','1');
    url.searchParams.set('origin',location.origin);
  }
  replayUrl = url;
  replayController = undefined;
  const session = ++replaySession;
  replayMessage('');
  delete $('replayStatus').dataset.providerError;
  $('replaySpeed').disabled = false;
  $('replaySpeed').value = '1';
  $('replayTitle').textContent = button.dataset.matchTitle || 'Match replay';
  updateReplayLink(replayPosition());
  replayDialog.showModal();
  if (isYouTubeReplay() && blockedYouTubeVideos.has(url.pathname)) {
    showYouTubeFallback(blockedYouTubeVideos.get(url.pathname));
    return;
  }
  replayFrame.src = url.href;
  replayReadyTimer = setTimeout(() => {
    if (session === replaySession && !replayController && !replayFrame.hidden) {
      replayMessage('If the player doesn’t start, open the recording using the link below.');
    }
  }, 8000);
  attachReplayControls(session).catch(() => {
    if (session === replaySession) replayMessage('Advanced controls are unavailable. You can still change the start time or open the recording.');
  });
});
$('closeReplay').addEventListener('click', () => replayDialog.close());
replayDialog.addEventListener('close', () => {
  clearTimeout(replayReadyTimer);
  replaySession++;
  replayUrl = undefined;
  replayController = undefined;
  const oldFrame = replayFrame;
  const player = oldFrame.replayInstance;
  replayFrame = oldFrame.cloneNode(false);
  replayFrame.removeAttribute('src');
  oldFrame.replaceWith(replayFrame);
  try {
    const disposal = player?.destroy();
    disposal?.catch?.(() => {});
  } catch {}
});
function wireSlidingIndicator(group, control, selected) {
  const indicator = group.querySelector('.nav-indicator');
  function sync(target = group.querySelector(selected)) {
    if (target) {
      indicator.style.transform = 'translateX(' + target.offsetLeft + 'px)';
      indicator.style.width = target.offsetWidth + 'px';
    }
    indicator.classList.toggle('shown', Boolean(target));
  }
  group.addEventListener('pointerover', (event) => {
    if (event.pointerType === 'touch') return;
    const target = event.target.closest(control);
    if (target) sync(target);
  });
  group.addEventListener('pointerleave', () => sync());
  group.addEventListener('focusin', (event) => sync(event.target));
  group.addEventListener('focusout', (event) => {
    if (!group.contains(event.relatedTarget)) sync();
  });
  const observer = new ResizeObserver(() => sync());
  observer.observe(group);
  group.querySelectorAll(control).forEach((item) => observer.observe(item));
  sync();
  return {sync, disconnect: () => observer.disconnect()};
}
const {sync: syncNav} = wireSlidingIndicator(topNav, 'a', '[aria-current]');

const eventSearchDialog = $('eventSearchDialog');
const eventQuery = $('eventQuery');
const eventSearchResults = $('eventSearchResults');
ui.browse.addEventListener('click', (event) => {
  if (!event.target.closest('[data-event-search]')) return;
  eventQuery.value = '';
  eventSearchResults.hidden = true;
  eventSearchResults.replaceChildren();
  eventSearchDialog.showModal();
});
eventQuery.addEventListener('input', () => {
  const query = eventQuery.value.trim().toLowerCase();
  eventSearchResults.hidden = !query;
  if (!query) return;
  const results = rows.filter((row) => [row.name, row.sku, locationText(row.location)]
    .join(' ').toLowerCase().includes(query)).slice(0, 10);
  eventSearchResults.innerHTML = results.length ? results.map((row) =>
    '<a href="/event/' + encodeURIComponent(row.sku) + '"><strong>' + escape(row.name) +
    '</strong><small>' + escape([dateRange(row), locationText(row.location)].filter(Boolean).join(' · ')) +
    '</small></a>').join('') : '<p>' + (loading ? 'Loading events…' : 'No events found.') + '</p>';
});
eventQuery.addEventListener('keydown', (event) => {
  if (event.key === 'ArrowDown' && !eventSearchResults.hidden) {
    event.preventDefault();
    eventSearchResults.querySelector('a')?.focus();
  }
});
$('eventSearchForm').addEventListener('submit', (event) => {
  event.preventDefault();
  if (!eventSearchResults.hidden) eventSearchResults.querySelector('a')?.click();
});
$('closeEventSearch').addEventListener('click', () => eventSearchDialog.close());
eventSearchDialog.addEventListener('click', (event) => {
  if (event.target === eventSearchDialog) eventSearchDialog.close();
});
window.addEventListener('hashchange', () => {
  if (eventSearchDialog.open) eventSearchDialog.close();
});

switchView();
if (!location.pathname.startsWith('/event/')) initialize();
