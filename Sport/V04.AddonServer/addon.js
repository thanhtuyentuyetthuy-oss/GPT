const http = require('http');
const fs = require('fs');
const path = require('path');

const HOST = process.env.ADDON_HOST || '0.0.0.0';
const PORT = Number(process.env.ADDON_PORT || 7000);
const SPORT_ROOT = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(SPORT_ROOT, '..');
const MANIFEST_PATH = path.join(SPORT_ROOT, 'TestFixtures', 'V04.1.Manifest.json');
const SOURCE_FIXTURE_PATH = path.join(SPORT_ROOT, 'TestFixtures', 'V04.0.PublicSourceFixtures.json');
const CATALOG_CACHE_ROOT = path.join(REPO_ROOT, 'Data', 'Cache', 'V02.Catalog');
const META_CACHE_ROOT = path.join(REPO_ROOT, 'Data', 'Cache', 'V02.Meta');
const STREAM_CACHE_ROOT = path.join(REPO_ROOT, 'Data', 'Cache', 'V02.Stream');

function readJson(filePath) {
  const text = fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
  return JSON.parse(text);
}

const manifest = readJson(MANIFEST_PATH);
const sourceFixture = readJson(SOURCE_FIXTURE_PATH);

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept',
    'Access-Control-Max-Age': '86400'
  };
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    ...corsHeaders(),
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

function sendText(res, status, body) {
  res.writeHead(status, {
    ...corsHeaders(),
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

function findLatestCatalogCache() {
  if (!fs.existsSync(CATALOG_CACHE_ROOT)) return null;
  const files = fs.readdirSync(CATALOG_CACHE_ROOT)
    .filter(name => /^catalog-\d{4}-\d{2}-\d{2}\.json$/.test(name))
    .sort()
    .reverse();
  if (files.length === 0) return null;
  return path.join(CATALOG_CACHE_ROOT, files[0]);
}

function safeEventId(rawId) {
  return String(rawId || '').replace(/^sports:event:/, '').replace(/\.json$/, '');
}

function findMetaCache(eventId) {
  if (!fs.existsSync(META_CACHE_ROOT)) return null;
  const safeId = safeEventId(eventId).replace(/[^0-9A-Za-z_.-]/g, '_');
  const candidate = path.join(META_CACHE_ROOT, `event-${safeId}.json`);
  return fs.existsSync(candidate) ? candidate : null;
}

function findStreamCache(eventId) {
  if (!fs.existsSync(STREAM_CACHE_ROOT)) return null;
  const safeId = safeEventId(eventId).replace(/[^0-9A-Za-z_.-]/g, '_');
  const candidate = path.join(STREAM_CACHE_ROOT, `event-${safeId}.json`);
  return fs.existsSync(candidate) ? candidate : null;
}

function resolveState(item) {
  const event = item.event || {};
  const status = String(event.status || '').toUpperCase();
  if (/FT|FINISHED|CANCEL|POST/.test(status)) return 'FINISHED';
  if (event.kickoffUtc) {
    const kickoff = new Date(event.kickoffUtc);
    if (!Number.isNaN(kickoff.getTime()) && kickoff <= new Date()) return 'LIVE-CANDIDATE';
  }
  return 'UPCOMING';
}

function buildCatalogFromCache(cachePath) {
  const payload = readJson(cachePath);
  const sourceItems = Array.isArray(payload.metas) ? payload.metas : [];
  const metas = sourceItems.map(item => {
    const state = resolveState(item);
    const marker = state === 'LIVE-CANDIDATE' ? '[LIVE] ' : state === 'UPCOMING' ? '[NEXT] ' : '[DONE] ';
    return {
      id: String(item.id),
      type: 'tv',
      name: `${marker}${item.name || 'Unknown Match'}`,
      poster: item.poster || undefined,
      description: item.description ? `${item.description} • State: ${state}` : `State: ${state}`,
      genres: ['FOOTBALL'],
      releaseInfo: item.releaseInfo || undefined,
      behaviorHints: { defaultVideoId: String(item.id) }
    };
  });

  return { metas, cacheMaxAge: 60 };
}

function buildMetaFromCache(eventId) {
  const cachePath = findMetaCache(eventId);
  if (!cachePath) return { error: `V0.2.3 meta cache not found for event ${safeEventId(eventId)}.` };
  const payload = readJson(cachePath);
  const event = payload.event || payload.meta || payload;
  const id = `sports:event:${safeEventId(eventId)}`;
  const name = event.strEvent || event.eventName || 'Selected Match';
  return { meta: { id, type: 'tv', name, description: event.strLeague || event.strSport || '', poster: event.strThumb || undefined, videos: [{ id, title: name, released: event.dateEvent || undefined }] } };
}

function buildStreamsFromCache(eventId) {
  const cachePath = findStreamCache(eventId);
  if (!cachePath) return { error: `V0.2.4 stream cache not found for event ${safeEventId(eventId)}.` };
  const payload = readJson(cachePath);
  const sourceUrl = String(payload.sourceUrl || '');
  if (!/^https?:\/\//i.test(sourceUrl)) return { error: `Cached sourceUrl is not a valid HTTP(S) URL for event ${safeEventId(eventId)}.` };
  const ttl = Number(payload.ttlSeconds || 120);
  return { streams: [{ name: 'Authorized public source', title: 'Public / authorized source', url: sourceUrl, behaviorHints: { bingeGroup: 'v046-authorized-public' } }], cacheMaxAge: ttl, meta: { id: `sports:event:${safeEventId(eventId)}`, sourcePolicy: 'AUTHORIZED-ONLY' } };
}

const server = http.createServer((req, res) => {
  try {
    if (req.method === 'OPTIONS') { res.writeHead(204, corsHeaders()); res.end(); return; }
    const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = decodeURIComponent(requestUrl.pathname).replace(/\/$/, '') || '/';
    if (req.method !== 'GET') { sendText(res, 405, 'Method Not Allowed'); return; }
    if (pathname === '/manifest.json') { sendJson(res, 200, manifest); return; }
    if (pathname === '/catalog/tv/vietnam-sports.json' || pathname === '/catalog/tv/vietnam-sports') {
      const cachePath = findLatestCatalogCache();
      if (!cachePath) { sendJson(res, 503, { error: 'V0.2.1 catalog cache not found.' }); return; }
      sendJson(res, 200, buildCatalogFromCache(cachePath)); return;
    }
    const metaMatch = pathname.match(/^\/meta\/tv\/([^/]+)(?:\.json)?$/);
    if (metaMatch) { const payload = buildMetaFromCache(safeEventId(metaMatch[1])); sendJson(res, payload.error ? 503 : 200, payload); return; }
    const streamMatch = pathname.match(/^\/stream\/tv\/([^/]+)(?:\.json)?$/);
    if (streamMatch) { const payload = buildStreamsFromCache(safeEventId(streamMatch[1])); sendJson(res, payload.error ? 503 : 200, payload); return; }
    if (pathname === '/health' || pathname === '/healthz') {
      sendJson(res, 200, { service: 'Vietnam Sports Hub', version: '0.4.6', status: 'OK', manifest: '/manifest.json', catalogSource: 'V0.2.1 DAILY CACHE', metaSource: 'V0.2.3 META CACHE', streamSource: 'V0.2.4 STREAM CACHE', sourcePolicy: 'AUTHORIZED-ONLY' }); return;
    }
    sendJson(res, 404, { error: 'Not Found' });
  } catch (error) { sendJson(res, 500, { error: error.message }); }
});

server.listen(PORT, HOST, () => {
  console.log(`Vietnam Sports Hub v0.4.6 listening on http://${HOST}:${PORT}`);
  console.log(`Manifest: http://127.0.0.1:${PORT}/manifest.json`);
  console.log(`Catalog : http://127.0.0.1:${PORT}/catalog/tv/vietnam-sports.json`);
  console.log(`Meta    : http://127.0.0.1:${PORT}/meta/tv/sports:event:2397275.json`);
  console.log(`Stream  : http://127.0.0.1:${PORT}/stream/tv/sports:event:2397275.json`);
  console.log('CORS    : enabled');
  console.log('Integration: cache-only adapters; no upstream API request from addon server');
});
