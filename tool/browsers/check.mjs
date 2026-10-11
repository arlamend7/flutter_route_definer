// npm ci --prefix tool/browsers; npx --prefix tool/browsers playwright install
// node tool/browsers/check.mjs example/build/web firefox|webkit [js|wasm]
import { firefox, webkit, chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { checkNavigation } from '../browser_scenarios.mjs';
const directory = path.resolve(process.argv[2] || 'example/build/web');
const engine = process.argv[3] || 'firefox';
const browserType = { firefox, webkit, chromium }[engine];
if (!browserType) throw new Error('Expected firefox, webkit or chromium');
const types = { '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm',
  '.html': 'text/html', '.json': 'application/json', '.ttf': 'font/ttf', '.png': 'image/png' };
const server = http.createServer((request, response) => {
  let file = path.resolve(directory, '.' + new URL(request.url, 'http://localhost').pathname);
  if (!file.startsWith(directory + path.sep) && file !== directory) { response.writeHead(403); response.end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { response.writeHead(404); response.end(); return; }
  response.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp', 'Cache-Control': 'no-store' });
  fs.createReadStream(file).pipe(response);
});
let browser;
try {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}/`;
  browser = await browserType.launch({ headless: true });
  const page = await browser.newPage();
  const exceptions = [];
  page.on('pageerror', error => exceptions.push(error.message));
  const evaluate = expression => page.evaluate(expression);
  const command = async (action = 'state', uri) => page.evaluate(request =>
    JSON.parse(globalThis.routeDefinerCheck(JSON.stringify(request))), { action, uri });
  const until = async predicate => {
    let last;
    for (let i = 0; i < 300; i++) {
      await new Promise(resolve => setTimeout(resolve, 100));
      if (!await evaluate('typeof globalThis.routeDefinerCheck === "function"')) continue;
      last = await command();
      if (predicate(last)) return last;
    }
    throw new Error('Browser condition timed out: ' + JSON.stringify(last));
  };
  await checkNavigation({ command, until, evaluate, base, exceptions,
    expectedWasm: process.argv[4] === 'wasm', browser: `${engine} ${browser.version()}`,
    navigate: url => page.goto(url), reload: () => page.reload(),
  });
} finally {
  await browser?.close();
  server.close();
}
