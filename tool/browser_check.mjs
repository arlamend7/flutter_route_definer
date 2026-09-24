// Node >=22, Chromium; run against a built example/lib/browser_check.dart.
// Usage: CHROME_BIN=/path/to/chrome node tool/browser_check.mjs example/build/web [js|wasm]
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
const directory = path.resolve(process.argv[2] || 'example/build/web');
const expectedWasm = process.argv[3] === 'wasm';
const chromePath = process.env.CHROME_BIN || (process.platform === 'darwin'
  ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : 'google-chrome');
const types = {
  '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.html': 'text/html', '.json': 'application/json', '.ttf': 'font/ttf', '.png': 'image/png'
};
const server = http.createServer((request, response) => {
  let file = path.resolve(directory, '.' + new URL(request.url, 'http://localhost').pathname);
  if (!file.startsWith(directory + path.sep) && file !== directory) {
    response.writeHead(403); response.end(); return;
  }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, {
    'Content-Type': types[path.extname(file)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cache-Control': 'no-store'
  });
  fs.createReadStream(file).pipe(response);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/`;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'route-definer-chrome-'));
const chrome = spawn(chromePath, ['--headless=new', '--no-first-run', '--no-default-browser-check',
  '--enable-unsafe-swiftshader', '--remote-debugging-port=0', '--user-data-dir=' + profile,
  ...(process.env.CI ? ['--no-sandbox'] : []), 'about:blank'], { stdio: 'ignore' });
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
let socket;
try {
  const portFile = path.join(profile, 'DevToolsActivePort');
  for (let i = 0; i < 100 && !fs.existsSync(portFile); i++) await pause(100);
  const [port, wsPath] = fs.readFileSync(portFile, 'utf8').trim().split('\n');
  socket = new WebSocket(`ws://127.0.0.1:${port}${wsPath}`);
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let id = 0;
  const pending = new Map();
  const exceptions = [];
  socket.addEventListener('message', event => {
    const data = JSON.parse(event.data);
    if (data.id) {
      const request = pending.get(data.id);
      if (!request) return;
      clearTimeout(request.timer); pending.delete(data.id);
      data.error ? request.reject(new Error(JSON.stringify(data.error))) : request.resolve(data.result);
    } else if (data.method === 'Runtime.exceptionThrown') {
      exceptions.push(data.params.exceptionDetails);
      console.error(JSON.stringify(data.params.exceptionDetails));
    }
  });
  const call = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const requestId = ++id;
    const timer = setTimeout(() => { pending.delete(requestId); reject(new Error(`CDP timeout: ${method}`)); }, 15000);
    pending.set(requestId, { resolve, reject, timer });
    socket.send(JSON.stringify({ id: requestId, method, params, ...(sessionId ? { sessionId } : {}) }));
  });
  const version = await call('Browser.getVersion');
  const { targetId } = await call('Target.createTarget', { url: 'about:blank' });
  const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
  await call('Runtime.enable', {}, sessionId);
  await call('Page.enable', {}, sessionId);
  const evaluate = async expression => {
    const result = await call('Runtime.evaluate', { expression, returnByValue: true }, sessionId);
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  const command = async (action = 'state', uri) => JSON.parse(await evaluate(
    `globalThis.routeDefinerCheck(${JSON.stringify(JSON.stringify({ action, uri }))})`));
  const until = async predicate => {
    let last;
    for (let i = 0; i < 160; i++) {
      await pause(100);
      if (!await evaluate('typeof globalThis.routeDefinerCheck === "function"')) continue;
      last = await command();
      if (predicate(last)) return last;
    }
    throw new Error('Browser condition timed out: ' + JSON.stringify(last));
  };
  await call('Page.navigate', { url: base }, sessionId);
  await until(s => s.title === 'Home /');
  await command('push', '/item/42?tag=a&tag=b#details');
  let state = await until(s => s.title.includes('Item /item/42') && s.built.includes('/item/42?tag=a&tag=b#details'));
  assert.equal(state.wasm, expectedWasm);
  assert.deepEqual(state.arguments, { source: 'browser' });
  assert.deepEqual(state.current, {
    path: '/item/42', pattern: '/item/:id', parameters: { id: '42' }, fragment: 'details'
  });
  assert.deepEqual(state.inspectionStack, state.stack);
  assert.equal(state.history.at(-1).action, 'push');
  assert.equal(state.history.at(-1).from, '/');
  assert.deepEqual(state.history.at(-1).stack, state.stack);
  assert.ok(!state.logs.join('\n').includes('/item/42'));
  assert.ok(!state.logs.join('\n').includes('details'));
  const ids = state.ids;
  const pushedUrl = await evaluate('location.href');
  assert.ok(pushedUrl.includes('/item/42?tag=a&tag=b#details'), pushedUrl);
  await evaluate('history.back()');
  state = await until(s => s.uri === '/' && s.title === 'Home /');
  assert.equal(state.history.at(-1).action, 'restore');
  await evaluate('history.forward()');
  state = await until(s => s.uri.startsWith('/item/42') && s.title.includes('Item /item/42'));
  assert.deepEqual(state.ids, ids);
  assert.deepEqual(state.arguments, { source: 'browser' });
  assert.equal(state.history.at(-1).action, 'restore');
  await call('Page.reload', {}, sessionId);
  state = await until(s => s.uri.startsWith('/item/42') && s.title.includes('Item /item/42'));
  assert.deepEqual(state.stack, ['/', '/item/42?tag=a&tag=b#details']);
  assert.ok(!state.history.some(e => e.action === 'push')); // History is not persisted across reload.
  await command('push', '/item/7');
  await until(s => s.title === 'Item /item/7');
  await command('pop');
  state = await until(s => s.selected === 42 && s.uri.startsWith('/item/42'));
  assert.equal(state.history.at(-1).action, 'pop');
  assert.equal(state.history.filter(e => e.action === 'pop').length, 1);
  assert.deepEqual(state.inspectionStack, state.stack);
  const historyLength = await evaluate('history.length');
  await command('replace', '/other');
  state = await until(s => s.title === 'Other /other');
  assert.equal(state.history.at(-1).action, 'replace');
  assert.equal(await evaluate('history.length'), historyLength);
  await command('go', '/redirect');
  state = await until(s => s.uri === '/other' && s.title === 'Other /other');
  assert.equal(state.history.at(-1).action, 'redirect');
  assert.equal(state.history.at(-1).from, '/redirect');
  await call('Page.navigate', { url: base + '#/item/99?tag=deep' }, sessionId);
  state = await until(s => s.uri === '/item/99?tag=deep' && s.title.includes('Item /item/99'));
  assert.deepEqual(state.stack, ['/', '/item/99?tag=deep']);
  await call('Page.reload', {}, sessionId);
  state = await until(s => s.uri === '/item/99?tag=deep' && s.title.includes('Item /item/99'));
  assert.equal(state.selected, -1);
  assert.deepEqual(state.errors, []);
  assert.ok(state.history.length <= 32);
  assert.deepEqual(exceptions, []);
  console.log(JSON.stringify({
    mode: expectedWasm ? 'wasm' : 'javascript', browser: version.product,
    passed: ['push', 'URL', 'title', 'back', 'forward', 'identity', 'arguments', 'reload', 'typed pop', 'replace', 'redirect', 'direct entry', 'current route', 'stack snapshots', 'event history', 'redacted diagnostics'], state
  }, null, 2));
  await call('Browser.close');
} finally {
  socket?.close(); chrome.kill(); server.close();
  await new Promise(resolve => chrome.exitCode != null ? resolve() : chrome.once('exit', resolve));
  fs.rmSync(profile, { recursive: true, force: true });
}
