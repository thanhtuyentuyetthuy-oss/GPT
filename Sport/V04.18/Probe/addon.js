const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 7018;
const HOST = '0.0.0.0';
const EVENT_ID = '2397275';
const EVENT_KEY = `sports:event:${EVENT_ID}`;
const TEST_STREAM_URL = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const ALLOWED_HOST = 'test-streams.mux.dev';
const ADDON_ID = 'org.vietnam.sports.hub.v0418probe';
const LOG_FILE = path.join(__dirname, 'requests.log');

const state = {
  manifestRequests: 0,
  catalogRequests: 0,
  metaRequests: 0,
  streamRequests: 0,
  streamHandlerMatched: false,
  streamResponseCount: 0,
  requests: []
};

function record(req, status) {
  const entry = {
    time: new Date().toISOString(),
    method: req.method,
    url: req.url,
    status
  };
  state.requests.push(entry);
  try { fs.appendFileSync(LOG_FILE, JSON.stringify(entry) + '\n', 'utf8'); } catch {}
}

function headers() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept',
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8'
  };
}

function send(res, req, data, status = 200) {
  record(req, status);
  res.writeHead(status, headers());
  res.end(JSON.stringify(data));
}

const manifest = {
  id: ADDON_ID,
  version: '0.4.18-probe',
  name: 'Vietnam Sports Hub - Stream Probe',
  description: 'Diagnostic addon for stream request resolution.',
  resources: ['catalog', 'meta', 'stream'],
  types: ['tv'],
  idPrefixes: ['sports:event:'],
  catalogs: [{ type: 'tv', id: 'v0418-probe', name: 'Vietnam Sports Probe' }],
  behaviorHints: { configurable: false }
};

const catalog = {
  metas: [{
    id: EVENT_KEY,
    type: 'tv',
    name: '[PROBE] Phoenix Rising vs Colorado Springs Switchbacks',
    description: 'Stream request resolution probe',
    genres: ['FOOTBALL'],
    behaviorHints: { defaultVideoId: EVENT_KEY }
  }],
  cacheMaxAge: 60
};

function handle(req, res) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, headers());
    return res.end();
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const p = decodeURIComponent(url.pathname.replace(/\/$/, '') || '/');

  if (p === '/manifest.json') return send(res, req, manifest);
  if (p === '/catalog/tv/v0418-probe.json' || p === '/catalog/tv/v0418-probe') return send(res, req, catalog);

  const meta = p.match(/^\/meta\/tv\/(.+?)(?:\.json)?$/);
  if (meta) {
    const id = meta[1].replace(/^sports:event:/, '');
    if (id !== EVENT_ID) return send(res, req, { error: 'Event not found' }, 404);
    return send(res, req, {
      meta: {
        id: EVENT_KEY,
        type: 'tv',
        name: 'Phoenix Rising vs Colorado Springs Switchbacks',
        description: 'Stream request resolution probe',
        videos: [{ id: EVENT_KEY, title: 'Phoenix Rising vs Colorado Springs Switchbacks' }]
      }
    });
  }

  const stream = p.match(/^\/stream\/tv\/(.+?)(?:\.json)?$/);
  if (stream) {
    const id = stream[1].replace(/^sports:event:/, '');
    state.streamRequests += 1;
    if (id !== EVENT_ID) return send(res, req, { error: 'Event not found' }, 404);
    state.streamHandlerMatched = true;
    state.streamResponseCount = 1;
    return send(res, req, {
      streams: [{
        name: 'Probe HLS source',
        title: 'Probe HLS stream',
        url: TEST_STREAM_URL,
        behaviorHints: {
          notWebReady: true,
          bingeGroup: 'v0418-probe',
          filename: 'x36xhzz.m3u8'
        }
      }],
      cacheMaxAge: 120,
      meta: { id: EVENT_KEY, sourcePolicy: 'AUTHORIZED-ONLY', sourceHost: ALLOWED_HOST }
    });
  }

  if (p === '/diagnostic.json') {
    return send(res, req, {
      streamRequestSeen: state.streamRequests > 0,
      streamHandlerMatched: state.streamHandlerMatched,
      streamResponseCount: state.streamResponseCount,
      manifestRequests: state.manifestRequests,
      catalogRequests: state.catalogRequests,
      metaRequests: state.metaRequests,
      requests: state.requests
    });
  }

  record(req, 404);
  res.writeHead(404, headers());
  res.end(JSON.stringify({ error: 'Not Found' }));
}

const server = http.createServer((req, res) => {
  const p = new URL(req.url, `http://${req.headers.host}`).pathname;
  if (p === '/manifest.json') state.manifestRequests += 1;
  else if (p.startsWith('/catalog/')) state.catalogRequests += 1;
  else if (p.startsWith('/meta/')) state.metaRequests += 1;
  handle(req, res);
});

server.listen(PORT, HOST, () => {
  console.log(`V0.4.18 Stream Request Probe listening on http://${HOST}:${PORT}`);
  console.log(`Manifest: http://127.0.0.1:${PORT}/manifest.json`);
  console.log(`Diagnostic: http://127.0.0.1:${PORT}/diagnostic.json`);
  console.log('Install the PROBE addon in Stremio and open the probe event once.');
  console.log('Keep this window open while testing.');
});
