const http = require('http');
const fs = require('fs');
const path = require('path');

const HOST = process.env.ADDON_HOST || '0.0.0.0';
const PORT = Number(process.env.ADDON_PORT || 7000);
const ROOT = path.resolve(__dirname, '..');
const MANIFEST_PATH = path.join(ROOT, 'TestFixtures', 'V04.1.Manifest.json');
const SOURCE_FIXTURE_PATH = path.join(ROOT, 'TestFixtures', 'V04.0.PublicSourceFixtures.json');

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
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

function buildCatalog() {
  return {
    metas: [
      {
        id: 'sports:event:2397275',
        type: 'tv',
        name: 'Vietnam Sports Hub Test Event',
        poster: '',
        description: 'V0.4.2 integration test item. Stream playback is not resolved by this server.'
      }
    ],
    cacheMaxAge: 60
  };
}

function buildMeta(id) {
  return {
    meta: {
      id,
      type: 'tv',
      name: 'Vietnam Sports Hub Test Event',
      description: 'V0.4.2 integration test metadata.',
      videos: [
        {
          id,
          title: 'Live event',
          released: new Date().toISOString()
        }
      ]
    }
  };
}

function buildStreams(id) {
  // V0.4.2 is intentionally a contract/server test.
  // It exposes fixture references but does not scrape, extract hidden endpoints,
  // bypass access controls, or resolve protected streams.
  const fixtures = sourceFixture.sources.map((item, index) => ({
    name: `Public fixture ${index + 1} - ${item.scope}`,
    title: item.name,
    url: item.url,
    behaviorHints: {
      bingeGroup: 'v04-fixture-test'
    }
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
    // Normalize percent-encoded event IDs before route matching so both
    // sports%3Aevent%3A2397275 and sports:event:2397275 work identically.
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
      sendJson(res, 200, buildCatalog());
      return;
    }

    const metaMatch = pathname.match(/^\/meta\/tv\/([^/]+)(?:\.json)?$/);
    if (metaMatch) {
      sendJson(res, 200, buildMeta(metaMatch[1]));
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
        version: '0.4.2',
        status: 'OK',
        manifest: '/manifest.json'
      });
      return;
    }

    sendJson(res, 404, { error: 'Not Found' });
  } catch (error) {
    sendJson(res, 500, { error: error.message });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Vietnam Sports Hub v0.4.2 listening on http://${HOST}:${PORT}`);
  console.log(`Manifest: http://127.0.0.1:${PORT}/manifest.json`);
  console.log(`Catalog : http://127.0.0.1:${PORT}/catalog/tv/vietnam-sports.json`);
  console.log(`Meta    : http://127.0.0.1:${PORT}/meta/tv/sports:event:2397275.json`);
  console.log(`Stream  : http://127.0.0.1:${PORT}/stream/tv/sports:event:2397275.json`);
  console.log('Policy  : public fixture references only; no extraction/bypass/protected resolution');
});
