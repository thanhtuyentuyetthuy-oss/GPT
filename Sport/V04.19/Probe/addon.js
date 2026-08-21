const http = require('http');

const PORT = 7019;
const HOST = '0.0.0.0';
const EVENT_ID = '2397275';
const EVENT_KEY = `sports:event:${EVENT_ID}`;
const MUX_URL = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const APPLE_URL = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
const ADDON_ID = 'org.vietnam.sports.hub.v0419probe';
const ALLOWED_HOSTS = new Set(['test-streams.mux.dev', 'devstreaming-cdn.apple.com']);

const state = {
  manifestRequests: 0,
  catalogRequests: 0,
  metaRequests: 0,
  streamRequests: 0,
  muxStreamRequests: 0,
  appleStreamRequests: 0,
  streamHandlerMatched: false,
  streamResponseCount: 0,
  requests: []
};

function headers() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, X-Requested-With, Content-Type, Accept',
    'Cache-Control': 'no-store',
    'Content-Type': 'application/json; charset=utf-8'
  };
}

function record(req, status) {
  state.requests.push({
    time: new Date().toISOString(),
    method: req.method,
    url: req.url,
    status
  });
}

function send(res, req, data, status = 200) {
  record(req, status);
  res.writeHead(status, headers());
  res.end(JSON.stringify(data));
}

function hostFor(url) {
  return new URL(url).hostname.toLowerCase();
}

function manifest() {
  return {
    id: ADDON_ID,
    version: '0.4.19-probe',
    name: 'Vietnam Sports Hub - HLS Source Probe',
    description: 'Diagnostic addon comparing two public HLS sources through one stream contract.',
    resources: ['catalog', 'meta', 'stream'],
    types: ['tv'],
    idPrefixes: ['sports:event:'],
    catalogs: [{ type: 'tv', id: 'v0419-probe', name: 'Vietnam Sports HLS Probe' }],
    behaviorHints: { configurable: false }
  };
}

function catalog() {
  return {
    metas: [{
      id: EVENT_KEY,
      type: 'tv',
      name: '[PROBE] Phoenix Rising vs Colorado Springs Switchbacks',
      description: 'HLS source differential probe',
      genres: ['FOOTBALL'],
      behaviorHints: { defaultVideoId: EVENT_KEY }
    }],
    cacheMaxAge: 60
  };
}

function meta() {
  return {
    meta: {
      id: EVENT_KEY,
      type: 'tv',
      name: 'Phoenix Rising vs Colorado Springs Switchbacks',
      description: 'HLS source differential probe',
      videos: [{ id: EVENT_KEY, title: 'Phoenix Rising vs Colorado Springs Switchbacks' }]
    }
  };
}

function buildStream(name, title, url, bingeGroup) {
  const host = hostFor(url);
  if (!ALLOWED_HOSTS.has(host)) throw new Error(`Source host not allowlisted: ${host}`);
  return {
    name,
    title,
    url,
    behaviorHints: {
      notWebReady: true,
      bingeGroup,
      filename: url.includes('bipbop') ? 'bipbop_4x3_variant.m3u8' : 'x36xhzz.m3u8'
    }
  };
}

function streamPayload() {
  const muxHost = hostFor(MUX_URL);
  const appleHost = hostFor(APPLE_URL);
  return {
    streams: [
      buildStream('Mux HLS control source', 'Mux HLS test stream', MUX_URL, 'v0419-mux'),
      buildStream('Apple HLS comparison source', 'Apple Bip Bop HLS test stream', APPLE_URL, 'v0419-apple')
    ],
    cacheMaxAge: 120,
    meta: {
      id: EVENT_KEY,
      sourcePolicy: 'AUTHORIZED-ONLY',
      sourceHosts: [muxHost, appleHost],
      comparisonMode: 'MUX-VS-APPLE'
    }
  };
}

function handle(req, res) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, headers());
    return res.end();
  }
  if (req.method !== 'GET') return send(res, req, { error: 'Method Not Allowed' }, 405);

  const url = new URL(req.url, `http://${req.headers.host}`);
  const p = decodeURIComponent(url.pathname.replace(/\/$/, '') || '/');

  if (p === '/manifest.json') {
    state.manifestRequests += 1;
    return send(res, req, manifest());
  }
  if (p === '/catalog/tv/v0419-probe.json' || p === '/catalog/tv/v0419-probe') {
    state.catalogRequests += 1;
    return send(res, req, catalog());
  }
  if (p.startsWith('/meta/tv/')) {
    state.metaRequests += 1;
    return send(res, req, meta());
  }
  if (p.startsWith('/stream/tv/')) {
    state.streamRequests += 1;
    state.muxStreamRequests += 1;
    state.appleStreamRequests += 1;
    state.streamHandlerMatched = true;
    state.streamResponseCount += 1;
    try {
      return send(res, req, streamPayload());
    } catch (err) {
      return send(res, req, { error: err.message }, 503);
    }
  }
  if (p === '/diagnostic.json') {
    return send(res, req, {
      streamRequestSeen: state.streamRequests > 0,
      streamHandlerMatched: state.streamHandlerMatched,
      streamResponseCount: state.streamResponseCount,
      muxStreamRequests: state.muxStreamRequests,
      appleStreamRequests: state.appleStreamRequests,
      manifestRequests: state.manifestRequests,
      catalogRequests: state.catalogRequests,
      metaRequests: state.metaRequests,
      requests: state.requests
    });
  }
  return send(res, req, { error: 'Not Found' }, 404);
}

http.createServer(handle).listen(PORT, HOST, () => {
  console.log(`V0.4.19 HLS Source Differential Probe listening on http://${HOST}:${PORT}`);
  console.log(`Manifest: http://127.0.0.1:${PORT}/manifest.json`);
  console.log(`Diagnostic: http://127.0.0.1:${PORT}/diagnostic.json`);
  console.log('Stream response now contains both Mux and Apple comparison sources.');
});
