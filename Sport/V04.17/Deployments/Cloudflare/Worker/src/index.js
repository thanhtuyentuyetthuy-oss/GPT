const EVENT_ID = '2397275';
const EVENT_KEY = `sports:event:${EVENT_ID}`;
const ALLOWED_HOSTS = new Set(['test-streams.mux.dev', 'stream.mux.com']);
const TEST_STREAM_URL = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

const MANIFEST = {
  id: 'org.vietnam.sports.hub',
  version: '0.4.17-cloudflare',
  name: 'Vietnam Sports Hub',
  description: 'Vietnam sports addon with Stremio HLS compatibility contract.',
  resources: ['catalog', 'meta', 'stream'],
  types: ['tv'],
  idPrefixes: ['sports:event:'],
  catalogs: [{
    type: 'tv',
    id: 'vietnam-sports',
    name: 'Vietnam Sports',
    extra: [{ name: 'search', isRequired: false }]
  }],
  behaviorHints: { configurable: false }
};

const CATALOG = [
  { id: 'sports:event:2397275', type: 'tv', name: '[DONE] Phoenix Rising vs Colorado Springs Switchbacks', description: 'State: FINISHED', genres: ['FOOTBALL'], behaviorHints: { defaultVideoId: 'sports:event:2397275' } },
  { id: 'sports:event:2397604', type: 'tv', name: '[DONE] Corpus Christi FC', description: 'State: FINISHED', genres: ['FOOTBALL'], behaviorHints: { defaultVideoId: 'sports:event:2397604' } },
  { id: 'sports:event:2407000', type: 'tv', name: '[DONE] Sporting', description: 'State: FINISHED', genres: ['FOOTBALL'], behaviorHints: { defaultVideoId: 'sports:event:2407000' } }
];

function headers(contentType = 'application/json; charset=utf-8') {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept',
    'Cache-Control': 'no-store',
    'Content-Type': contentType
  };
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: headers() });
}

function isAuthorizedStream(url) {
  try {
    const u = new URL(url);
    return (u.protocol === 'https:' || u.protocol === 'http:') && ALLOWED_HOSTS.has(u.hostname.toLowerCase());
  } catch {
    return false;
  }
}

function metaFor(eventId) {
  const id = `sports:event:${eventId}`;
  const entry = CATALOG.find((x) => x.id === id);
  if (!entry) return null;
  const title = entry.name.replace(/^\[(LIVE|NEXT|DONE)\]\s*/, '');
  return { meta: { id, type: 'tv', name: title, description: 'Vietnam Sports Hub test deployment', videos: [{ id, title }] } };
}

function streamFor(eventId) {
  if (eventId !== EVENT_ID) return json({ error: `Test stream fixture is available only for event ${EVENT_ID}.` }, 404);
  if (!isAuthorizedStream(TEST_STREAM_URL)) return json({ error: 'Configured stream host is not allowlisted.' }, 503);
  return json({
    streams: [{
      name: 'Public test source',
      title: 'Public HLS test stream',
      url: TEST_STREAM_URL,
      behaviorHints: {
        notWebReady: true,
        bingeGroup: 'v047-public-test',
        filename: 'x36xhzz.m3u8'
      }
    }],
    cacheMaxAge: 120,
    meta: {
      id: EVENT_KEY,
      sourcePolicy: 'AUTHORIZED-ONLY',
      sourceHost: 'test-streams.mux.dev',
      streamCompatibility: 'STREMIO-HLS-NOT-WEB-READY'
    }
  });
}

export default {
  async fetch(request) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: headers() });
    if (request.method !== 'GET') return json({ error: 'Method Not Allowed' }, 405);

    const url = new URL(request.url);
    const path = decodeURIComponent(url.pathname.replace(/\/$/, '') || '/');

    if (path === '/manifest.json') return json(MANIFEST);
    if (path === '/health' || path === '/healthz') {
      return json({
        service: 'Vietnam Sports Hub',
        deployment: 'CLOUDFLARE-WORKERS',
        version: '0.4.17-cloudflare',
        status: 'OK',
        sourcePolicy: 'AUTHORIZED-ONLY',
        sourceGate: 'ALLOWLISTED-PUBLIC-TEST-HOSTS',
        runtime: 'EDGE',
        upstreamRequests: 0,
        localHostDependency: false,
        streamCompatibility: 'STREMIO-HLS-NOT-WEB-READY'
      });
    }
    if (path === '/catalog/tv/vietnam-sports.json' || path === '/catalog/tv/vietnam-sports') return json({ metas: CATALOG, cacheMaxAge: 60 });

    const metaMatch = path.match(/^\/meta\/tv\/([^/]+?)(?:\.json)?$/);
    if (metaMatch) {
      const payload = metaFor(metaMatch[1].replace(/^sports:event:/, ''));
      return payload ? json(payload) : json({ error: 'Event not found.' }, 404);
    }

    const streamMatch = path.match(/^\/stream\/tv\/([^/]+?)(?:\.json)?$/);
    if (streamMatch) return streamFor(streamMatch[1].replace(/^sports:event:/, ''));

    return json({ error: 'Not Found' }, 404);
  }
};
