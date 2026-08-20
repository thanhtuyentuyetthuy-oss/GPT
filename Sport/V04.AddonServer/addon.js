const http = require('http');
const fs = require('fs');
const path = require('path');

const HOST = process.env.ADDON_HOST || '0.0.0.0';
const PORT = Number(process.env.ADDON_PORT || 7000);
const SPORT_ROOT = path.resolve(__dirname, '..');
const REPO_ROOT = path.resolve(SPORT_ROOT, '..');
const MANIFEST_PATH = path.join(SPORT_ROOT, 'TestFixtures', 'V04.1.Manifest.json');
const SOURCE_FIXTURE_PATH = path.join(SPORT_ROOT, 'TestFixtures', 'V04.0.PublicSourceFixtures.json');
const CACHE_ROOT = path.join(REPO_ROOT, 'Data', 'Cache', 'V02.Catalog');

function readJson(filePath) {
  const text = fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
  return JSON.parse(text);
}

const manifest = readJson(MANIFEST_PATH);
const sourceFixture = readJson(SOURCE_FIXTURE_PATH);

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

function sendText(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-store',
    'Content-Length': Buffer.byteLength(body)
  });
  res.end(body);
}

function findLatestCatalogCache() {
  if (!fs.existsSync(CACHE_ROOT)) return null;
  const files = fs.readdirSync(CACHE_ROOT)
    .filter(name => /^catalog-\d{4}-\d{2}-\d{2}\.json$/.test(name))
    .sort()
    .reverse();
  if (files.length === 0) return null;
  return path.join(CACHE_ROOT, files[0]);
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

function buildLegacyMeta(id) {
  return {
    meta: {
      id,
      type: 'tv',
      name: 'Vietnam Sports Hub Test Event',
      description: 'V0.4.2 integration test metadata.',
      videos: [
        { id, title: 'Live event', released: new Date().toISOString() }
      ]
    }
  };
}

function buildStreams(id) {
  const fixtures = sourceFixture.sources.map((item, index) => ({
    name: `Public fixture ${index + 1} - ${item.scope}`,
    title: item.name,
    url: item.url,
    behaviorHints: { bingeGroup: 'v04-fixture-test' }
  }));

  return {
    streams: fixtures.slice(0, 3),
    cacheMaxAge: 120,
    staleRevalidate: 120,
    staleError: 300,
    meta: { id }
  };
}

const server = http.createServer((req, res) => {
  try {
    const requestUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = decodeURIComponent(requestUrl.pathname).replace(/\/$/, '') || '/';

    if (req.method !== 'GET') {
      sendText(res, 405, 'Method Not Allowed');
      return;
    }

    if (pathname === '/manifest.json') {
      sendJson(res, 200, manifest);
      return;
    }

    if (pathname === '/catalog/tv/vietnam-sports.json' || pathname === '/catalog/tv/vietnam-sports') {
      const cachePath = findLatestCatalogCache();
      if (!cachePath) {
        sendJson(res, 503, { error: 'V0.2.1 catalog cache not found.' });
        return;
      }
      sendJson(res, 200, buildCatalogFromCache(cachePath));
      return;
    }

    const metaMatch = pathname.match(/^\/meta\/tv\/([^/]+)(?:\.json)?$/);
    if (metaMatch) {
      sendJson(res, 200, buildLegacyMeta(metaMatch[1]));
      return;
    }

    const streamMatch = pathname.match(/^\/stream\/tv\/([^/]+)(?:\.json)?$/);
    if (streamMatch) {
      sendJson(res, 200, buildStreams(streamMatch[1]));
      return;
    }

    if (pathname === '/health' || pathname === '/healthz') {
      sendJson(res, 200, {
        service: 'Vietnam Sports Hub',
        version: '0.4.3',
        status: 'OK',
        manifest: '/manifest.json',
        catalogSource: 'V0.2.1 DAILY CACHE'
      });
      return;
    }

    sendJson(res, 404, { error: 'Not Found' });
  } catch (error) {
    sendJson(res, 500, { error: error.message });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Vietnam Sports Hub v0.4.3 listening on http://${HOST}:${PORT}`);
  console.log(`Manifest: http://127.0.0.1:${PORT}/manifest.json`);
  console.log(`Catalog : http://127.0.0.1:${PORT}/catalog/tv/vietnam-sports.json`);
  console.log(`Catalog cache root: ${CACHE_ROOT}`);
  console.log(`Meta    : http://127.0.0.1:${PORT}/meta/tv/sports:event:2397275.json`);
  console.log(`Stream  : http://127.0.0.1:${PORT}/stream/tv/sports:event:2397275.json`);
  console.log('Catalog : V0.2.1 daily cache only; no source API request from addon server');
});
