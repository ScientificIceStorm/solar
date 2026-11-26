const routes = {
  '/api/seasons': [],
  '/api/skills': ['seasonId', 'gradeLevel'],
  '/api/events': ['seasonId'],
  '/api/webcasts': ['seasonId'],
  '/api/openskill': ['seasonId', 'gradeLevel'],
  '/api/team': ['seasonId', 'number', 'summary', 'upcoming'],
  '/api/event': ['sku', 'division', 'information', 'roster', 'streams', 'history', 'scouting', 'seasonId'],
};

function error(message, status) {
  return Response.json({error: message}, {status, headers: {'Cache-Control': 'no-store'}});
}

// ---------------------------------------------------------------------------------------
// ScoutVision shared training data. Visitors who turn on sharing in the Match studio send the
// frames they checked plus their answers (never whole videos). Stored in the R2 bucket bound
// as CONTRIBUTIONS; the owner downloads them with tools/pull_contributions.py to retrain.
// ---------------------------------------------------------------------------------------
const GOAL_IDS = ['far-neutral', 'far-blue', 'left-neutral', 'left-red', 'midfield', 'right-blue',
  'right-neutral', 'near-red', 'near-neutral'];
const WALL_IDS = ['far', 'left', 'right', 'near'];
const MAX_BODY = 1_500_000, MAX_IMAGE = 700_000, PER_HOUR = 150;

const text = (value, max) => typeof value === 'string' ? value.slice(0, max) : '';
const unit = value => typeof value === 'number' && Number.isFinite(value) && value >= -0.5 && value <= 1.5;

function cleanGoals(goals) {
  if (!goals || typeof goals !== 'object') return null;
  const out = {};
  for (const id of GOAL_IDS) {
    if (!(id in goals)) continue;
    const counts = goals[id];
    if (counts === null) { out[id] = null; continue; }
    if (!Array.isArray(counts) || counts.length !== 3 ||
        !counts.every(n => Number.isInteger(n) && n >= 0 && n <= 12)) return null;
    out[id] = counts;
  }
  return out;
}

function cleanToggles(toggles) {
  if (!toggles || typeof toggles !== 'object') return null;
  const out = {};
  for (const wall of WALL_IDS) {
    if (!(wall in toggles)) continue;
    const owner = toggles[wall];
    if (owner !== null && ![0, 1, 2].includes(owner)) return null;
    out[wall] = owner;
  }
  return out;
}

async function tooMany(request) {
  // Rough per-visitor hourly limit using the edge cache (no IPs are stored anywhere).
  const visitor = request.headers.get('CF-Connecting-IP') || 'unknown';
  const hour = Math.floor(Date.now() / 3_600_000);
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(visitor + ':' + hour));
  const key = new Request('https://scoutvision-rate.invalid/' + [...new Uint8Array(digest)].slice(0, 12)
    .map(b => b.toString(16).padStart(2, '0')).join(''));
  const cache = globalThis.caches?.default;
  if (!cache) return false;
  const count = Number(await (await cache.match(key))?.text() || 0);
  if (count >= PER_HOUR) return true;
  await cache.put(key, new Response(String(count + 1), {headers: {'Cache-Control': 'max-age=3600'}}));
  return false;
}

async function contribute(request, env, ctx) {
  if (!env.CONTRIBUTIONS) return error('Sharing is not set up yet.', 503);
  if (request.method !== 'POST') return error('Method not allowed.', 405);
  if (Number(request.headers.get('Content-Length') || 0) > MAX_BODY) return error('This upload is too large.', 413);
  if (await tooMany(request)) return error('Too many uploads. Try again in an hour.', 429);
  let body;
  try {
    const raw = await request.text();
    if (raw.length > MAX_BODY) return error('This upload is too large.', 413);
    body = JSON.parse(raw);
  } catch { return error('Invalid upload.', 400); }
  if (body?.version !== 1 || !['scoring', 'robots'].includes(body.kind)) return error('Invalid upload.', 400);
  let image;
  try { image = Uint8Array.from(atob(text(body.image, MAX_IMAGE * 1.4)), c => c.charCodeAt(0)); }
  catch { return error('Invalid image.', 400); }
  if (image.length < 1000 || image.length > MAX_IMAGE || image[0] !== 0xff || image[1] !== 0xd8 || image[2] !== 0xff) {
    return error('Invalid image.', 400);
  }
  const record = {
    version: 1, kind: body.kind, receivedAt: new Date().toISOString(), country: request.cf?.country || null,
    event: text(body.event, 180), round: text(body.round, 100),
    teams: Array.isArray(body.teams) ? body.teams.slice(0, 4).map(team => text(team, 9)) : [],
    clip: /^[0-9a-f]{8,64}$/.test(body.clip || '') ? body.clip : null,
    at: typeof body.at === 'number' && Number.isFinite(body.at) ? body.at : null,
    width: Number.isInteger(body.width) && body.width <= 4096 ? body.width : null,
    height: Number.isInteger(body.height) && body.height <= 4096 ? body.height : null,
    source: text(body.source, 20),
  };
  if (body.kind === 'scoring') {
    const corners = Array.isArray(body.corners) && body.corners.length === 4 &&
      body.corners.every(c => Array.isArray(c) && c.length === 2 && c.every(unit)) ? body.corners : null;
    const goals = cleanGoals(body.goals), toggles = cleanToggles(body.toggles);
    if (!corners || !WALL_IDS.includes(body.wall) || !goals || !toggles) return error('Invalid answers.', 400);
    Object.assign(record, {corners, wall: body.wall, goals, toggles});
  } else {
    const boxes = Array.isArray(body.boxes) && body.boxes.length <= 12 && body.boxes.every(b =>
      b && [b.x, b.y, b.w, b.h].every(v => typeof v === 'number' && v >= 0 && v <= 1)) ? body.boxes : null;
    if (!boxes) return error('Invalid boxes.', 400);
    record.boxes = boxes.map(({x, y, w, h}) => ({x, y, w, h}));
  }
  const key = `v1/${body.kind}/${record.receivedAt.slice(0, 10)}/${crypto.randomUUID()}`;
  await env.CONTRIBUTIONS.put(key + '.jpg', image, {httpMetadata: {contentType: 'image/jpeg'}});
  await env.CONTRIBUTIONS.put(key + '.json', JSON.stringify(record), {httpMetadata: {contentType: 'application/json'}});
  return Response.json({ok: true, id: key}, {headers: {'Cache-Control': 'no-store'}});
}

// Owner-only download: list and fetch stored contributions with the admin token.
async function contributions(request, env, url) {
  if (request.method !== 'GET') return error('Method not allowed.', 405);
  const token = env.SCOUTVISION_ADMIN_TOKEN;
  if (!env.CONTRIBUTIONS || !token) return error('Sharing is not set up yet.', 503);
  const given = (request.headers.get('Authorization') || '').replace(/^Bearer /, '');
  const a = new TextEncoder().encode(given), b = new TextEncoder().encode(token);
  let same = a.length === b.length ? 0 : 1;
  for (let i = 0; i < Math.min(a.length, b.length); i++) same |= a[i] ^ b[i];
  if (same) return error('Not allowed.', 401);
  const rest = url.pathname.slice('/api/scoutvision/contributions'.length).replace(/^\//, '');
  if (!rest) {
    const listing = await env.CONTRIBUTIONS.list({prefix: url.searchParams.get('prefix') || 'v1/',
      cursor: url.searchParams.get('cursor') || undefined, limit: 1000});
    return Response.json({objects: listing.objects.map(o => ({key: o.key, size: o.size, uploaded: o.uploaded})),
      cursor: listing.truncated ? listing.cursor : null}, {headers: {'Cache-Control': 'no-store'}});
  }
  const object = await env.CONTRIBUTIONS.get(decodeURIComponent(rest));
  if (!object) return error('Not found.', 404);
  return new Response(object.body, {headers: {'Content-Type': object.httpMetadata?.contentType || 'application/octet-stream',
    'Cache-Control': 'no-store'}});
}

// YouTube blocks page reads from Solar's API host, so the API lists an event
// channel's broadcasts through here. Only the API (holding the origin token)
// may call it, and only for a channel's public stream list. (Broadcast timing
// comes from the YouTube Data API: YouTube refuses watch pages here too.)
const youtubePage = /^\/(?:@[\w.-]{1,100}\/streams|(?:channel|c|user)\/[\w.-]{1,100}\/streams)$/;
async function youtubeRelay(request, env, url) {
  const token = env.SOLAR_ORIGIN_TOKEN;
  if (!token) return error('Not allowed.', 401);
  const a = new TextEncoder().encode(request.headers.get('X-Solar-Origin-Token') || '');
  const b = new TextEncoder().encode(token);
  let same = a.length === b.length ? 0 : 1;
  for (let i = 0; i < Math.min(a.length, b.length); i++) same |= a[i] ^ b[i];
  if (same) return error('Not allowed.', 401);
  let target;
  try { target = new URL(url.searchParams.get('url') || ''); } catch { return error('Invalid page.', 400); }
  if (target.protocol !== 'https:' || target.host !== 'www.youtube.com' || !youtubePage.test(target.pathname) ||
      target.search) {
    return error('Invalid page.', 400);
  }
  const page = await fetch(target, {headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cookie': 'CONSENT=YES+1; SOCS=CAI',
  }, redirect: 'follow'});
  return new Response(page.body, {status: page.status,
    headers: {'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store'}});
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/api/')) {
      if (/^\/(team\/[a-z0-9]+|event\/(?:RE|VE)-[a-z0-9-]+)\/?$/i.test(url.pathname)) {
        return env.ASSETS.fetch(new URL('/', url));
      }
      return env.ASSETS.fetch(request);
    }

    if (url.pathname === '/api/youtube-relay') return youtubeRelay(request, env, url);
    if (url.pathname === '/api/scoutvision/contribute') return contribute(request, env, ctx);
    if (url.pathname === '/api/scoutvision/contributions' || url.pathname.startsWith('/api/scoutvision/contributions/')) {
      return contributions(request, env, url);
    }
    if (request.method !== 'GET') return error('Method not allowed.', 405);
    if (url.pathname === '/api/profile-config') {
      if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) return error('Profile is awaiting setup.', 503);
      return Response.json({url: env.SUPABASE_URL, key: env.SUPABASE_PUBLISHABLE_KEY},
        {headers: {'Cache-Control': 'no-store'}});
    }
    const keys = routes[url.pathname];
    if (!keys) return error('Unknown API route.', 404);
    if (url.search.length > 300) return error('Invalid filters.', 400);
    let origin;
    try { origin = new URL(env.SOLAR_API_ORIGIN); } catch {}
    const local = ['localhost', '127.0.0.1'].includes(url.hostname) &&
      ['localhost', '127.0.0.1'].includes(origin?.hostname) && origin?.protocol === 'http:';
    if (!origin || origin.username || origin.password || origin.host === url.host ||
        (!local && (origin.protocol !== 'https:' || !env.SOLAR_ORIGIN_TOKEN))) {
      return error('Solar’s data service is not configured.', 503);
    }
    const target = new URL(url.pathname, origin);
    for (const key of keys) {
      if (url.searchParams.has(key)) target.searchParams.set(key, url.searchParams.get(key));
    }
    const headers = {Accept: 'application/json'};
    if (env.SOLAR_ORIGIN_TOKEN) headers['X-Solar-Origin-Token'] = env.SOLAR_ORIGIN_TOKEN;

    const cacheNamespace = url.pathname === '/api/openskill' ? '/solar-ratings-v3' : '/solar-cache-v2';
    const cacheUrl = new URL(cacheNamespace + target.pathname, url.origin);
    cacheUrl.search = target.search;
    const cacheKey = new Request(cacheUrl);
    const cache = !local && globalThis.caches?.default;
    const cached = cache ? await cache.match(cacheKey).catch(() => null) : null;
    const freshFor = url.pathname === '/api/seasons' ? 900 :
      url.pathname === '/api/openskill' ? 300 : 25;
    const refresh = async () => {
    try {
      const response = await fetch(target, {
        headers, redirect: 'manual', signal: AbortSignal.timeout(20000),
      });
      if ((response.status >= 300 && response.status < 400) ||
          !response.headers.get('Content-Type')?.includes('application/json')) {
        return error('Solar’s data service is temporarily unavailable.', 502);
      }
      const result = new Response(response.body, {
        status: response.status,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Cache-Control': response.ok ? response.headers.get('Cache-Control') || 'no-store' : 'no-store',
          'X-Solar-Live': response.headers.get('X-Solar-Live') || '0',
        },
      });
      if (response.ok && cache && !response.headers.get('Cache-Control')?.includes('no-store')) {
        const entry = result.clone();
        entry.headers.set('Cache-Control', 'public, max-age=86400');
        entry.headers.set('X-Solar-Cached-At', String(Date.now()));
        ctx.waitUntil(cache.put(cacheKey, entry).catch(() => {}));
      }
      return result;
    } catch (cause) {
      console.warn('Solar API request failed:', cause.name, cause.message);
      return error('Solar’s data service is temporarily unavailable.', 503);
    }
    };
    if (!cached) return refresh();
    if (cached.headers.get('X-Solar-Live') === '1' &&
        Date.now() - Number(cached.headers.get('X-Solar-Cached-At')) > 5000) {
      const result = await refresh();
      if (result.ok) return result;
    }
    if (Date.now() - Number(cached.headers.get('X-Solar-Cached-At')) > freshFor * 1000) {
      ctx.waitUntil(refresh().then((response) => response.body?.cancel()));
    }
    return new Response(cached.body, {
      headers: {'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'public, max-age=10'},
    });
  },
};
