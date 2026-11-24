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

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/api/')) {
      if (/^\/(team\/[a-z0-9]+|event\/(?:RE|VE)-[a-z0-9-]+)\/?$/i.test(url.pathname)) {
        return env.ASSETS.fetch(new URL('/', url));
      }
      return env.ASSETS.fetch(request);
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
