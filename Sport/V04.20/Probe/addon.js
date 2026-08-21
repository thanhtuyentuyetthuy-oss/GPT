const http = require('http');

const PORT = 7020;
const HOST = '0.0.0.0';
const EVENT_ID = '2397275';
const EVENT_KEY = `sports:event:${EVENT_ID}`;
const MP4_URL = 'https://github.com/video-commander/public-test-streams/releases/latest/download/BigBuckBunny.mp4';
const MUX_URL = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
const APPLE_URL = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8';
const ADDON_ID = 'org.vietnam.sports.hub.v0420probe';
const ALLOWED_HOSTS = new Set([new URL(MP4_URL).hostname, new URL(MUX_URL).hostname, new URL(APPLE_URL).hostname]);

const state = {
  manifestRequests: 0,
  catalogRequests: 0,
  metaRequests: 0,
  streamRequests: 0,
  mp4Requests: 0,
  muxRequests: 0,
  appleRequests: 0,
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
function record(req, status) { state.requests.push({ time: new Date().toISOString(), method: req.method, url: req.url, status }); }
function send(res, req, data, status = 200) { record(req, status); res.writeHead(status, headers()); res.end(JSON.stringify(data)); }
function makeStream(name, title, url, notWebReady, group, filename) {
  const host = new URL(url).hostname.toLowerCase();
  if (!ALLOWED_HOSTS.has(host)) throw new Error(`Unauthorized source host: ${host}`);
  return { name, title, url, behaviorHints: { notWebReady, bingeGroup: group, filename } };
}

function manifest() {
  return { id: ADDON_ID, version: '0.4.20-probe', name: 'Vietnam Sports Hub - Playback Matrix', description: 'MP4 vs HLS playback compatibility probe.', resources: ['catalog','meta','stream'], types: ['tv'], idPrefixes: ['sports:event:'], catalogs: [{ type:'tv', id:'v0420-probe', name:'Vietnam Sports Playback Matrix' }], behaviorHints: { configurable:false } };
}
function catalog() { return { metas: [{ id: EVENT_KEY, type:'tv', name:'[PROBE] Phoenix Rising vs Colorado Springs Switchbacks', description:'MP4 vs HLS playback compatibility probe', genres:['FOOTBALL'], behaviorHints:{defaultVideoId:EVENT_KEY} }], cacheMaxAge:60 }; }
function meta() { return { meta:{ id:EVENT_KEY, type:'tv', name:'Phoenix Rising vs Colorado Springs Switchbacks', description:'Playback compatibility matrix', videos:[{id:EVENT_KEY,title:'Phoenix Rising vs Colorado Springs Switchbacks'}] } }; }
function streamPayload() {
  const mp4 = makeStream('MP4 control source','MP4 web-ready control source',MP4_URL,false,'v0420-mp4','BigBuckBunny.mp4');
  const mux = makeStream('Mux HLS comparison source','Mux HLS comparison source',MUX_URL,true,'v0420-mux','x36xhzz.m3u8');
  const apple = makeStream('Apple HLS comparison source','Apple Bip Bop HLS comparison source',APPLE_URL,true,'v0420-apple','bipbop_4x3_variant.m3u8');
  return { streams:[mp4,mux,apple], cacheMaxAge:120, meta:{ id:EVENT_KEY, sourcePolicy:'AUTHORIZED-ONLY', matrixMode:'MP4-VS-HLS', sourceHosts:[new URL(MP4_URL).hostname,new URL(MUX_URL).hostname,new URL(APPLE_URL).hostname] } };
}
function handle(req,res) {
  if (req.method === 'OPTIONS') { res.writeHead(204, headers()); return res.end(); }
  if (req.method !== 'GET') return send(res,req,{error:'Method Not Allowed'},405);
  const u = new URL(req.url,`http://${req.headers.host}`); const p = decodeURIComponent(u.pathname.replace(/\/$/,'')||'/');
  if (p==='/manifest.json') { state.manifestRequests++; return send(res,req,manifest()); }
  if (p==='/catalog/tv/v0420-probe.json'||p==='/catalog/tv/v0420-probe') { state.catalogRequests++; return send(res,req,catalog()); }
  if (p.startsWith('/meta/tv/')) { state.metaRequests++; return send(res,req,meta()); }
  if (p.startsWith('/stream/tv/')) { state.streamRequests++; state.mp4Requests++; state.muxRequests++; state.appleRequests++; return send(res,req,streamPayload()); }
  if (p==='/diagnostic.json') return send(res,req,{streamRequestSeen:state.streamRequests>0,streamResponseCount:state.streamRequests,mp4Requests:state.mp4Requests,muxRequests:state.muxRequests,appleRequests:state.appleRequests,manifestRequests:state.manifestRequests,catalogRequests:state.catalogRequests,metaRequests:state.metaRequests,requests:state.requests});
  return send(res,req,{error:'Not Found'},404);
}

http.createServer(handle).listen(PORT,HOST,()=>{ console.log(`V0.4.20 Playback Matrix Probe listening on http://${HOST}:${PORT}`); console.log(`Manifest: http://127.0.0.1:${PORT}/manifest.json`); console.log(`Diagnostic: http://127.0.0.1:${PORT}/diagnostic.json`); });
