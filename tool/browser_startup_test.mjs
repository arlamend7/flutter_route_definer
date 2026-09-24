import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { PassThrough } from 'node:stream';
import test from 'node:test';
import { waitForDevTools } from './browser_startup.mjs';

async function fixture(t) {
  const profile = await mkdtemp(path.join(os.tmpdir(), 'route-definer-startup-'));
  const chrome = Object.assign(new EventEmitter(), {
    exitCode: null, signalCode: null, stderr: new PassThrough()
  });
  t.after(() => rm(profile, { recursive: true, force: true }));
  return { chrome, profile, file: path.join(profile, 'DevToolsActivePort') };
}

test('waits for a delayed and partially written port file', async t => {
  const { chrome, profile, file } = await fixture(t);
  const ready = waitForDevTools(chrome, profile, { timeoutMs: 1000, pollMs: 5 });
  await writeFile(file, '9222\n');
  await new Promise(resolve => setTimeout(resolve, 30));
  await writeFile(file, '9222\n/devtools/browser/test-id\n');
  assert.equal(await ready, 'ws://127.0.0.1:9222/devtools/browser/test-id');
  assert.equal(chrome.listenerCount('error'), 0);
});

test('reports early exit and Chrome stderr', async t => {
  const { chrome, profile } = await fixture(t);
  const ready = waitForDevTools(chrome, profile, { timeoutMs: 1000, pollMs: 5 });
  chrome.stderr.write('Chrome could not initialize');
  chrome.exitCode = 1;
  await assert.rejects(ready, /code=1.*\nChrome could not initialize/);
});

test('reports executable spawn errors', async t => {
  const { chrome, profile } = await fixture(t);
  const ready = waitForDevTools(chrome, profile, { timeoutMs: 1000, pollMs: 5 });
  chrome.emit('error', new Error('spawn missing-chrome ENOENT'));
  await assert.rejects(ready, /spawn missing-chrome ENOENT/);
});

test('reports a bounded startup timeout rather than a file-read error', async t => {
  const { chrome, profile } = await fixture(t);
  await assert.rejects(waitForDevTools(chrome, profile, { timeoutMs: 30, pollMs: 5 }),
    /DevToolsActivePort was not ready within 30ms/);
});
