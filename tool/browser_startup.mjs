import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { setTimeout as pause } from 'node:timers/promises';

// Listen immediately after spawn so early process errors are not discarded.
export async function waitForDevTools(chrome, profile, { timeoutMs = 30000, pollMs = 100 } = {}) {
  let stderr = '';
  let spawnError;
  const onData = chunk => { stderr = (stderr + chunk.toString()).slice(-16384); };
  const onError = error => { spawnError = error; };
  chrome.stderr?.on('data', onData);
  chrome.on('error', onError);
  const failure = reason => new Error(`Chrome startup failed: ${reason}\n${stderr || '(no Chrome stderr)'}`);
  const deadline = Date.now() + timeoutMs;
  try {
    while (Date.now() < deadline) {
      if (spawnError) throw failure(spawnError.message);
      if (chrome.exitCode !== null || chrome.signalCode !== null) {
        throw failure(`exited before DevTools was ready (code=${chrome.exitCode}, signal=${chrome.signalCode})`);
      }
      try {
        const contents = await readFile(path.join(profile, 'DevToolsActivePort'), 'utf8');
        const [port, socketPath] = contents.trim().split('\n');
        // The file can exist before Chrome finishes writing both lines.
        if (/^\d+$/.test(port) && Number(port) > 0 && Number(port) <= 65535 &&
            socketPath?.startsWith('/devtools/browser/')) {
          return `ws://127.0.0.1:${port}${socketPath}`;
        }
      } catch (error) {
        if (error.code !== 'ENOENT') throw error;
      }
      await pause(pollMs);
    }
    throw failure(`DevToolsActivePort was not ready within ${timeoutMs}ms`);
  } finally {
    chrome.stderr?.off('data', onData);
    chrome.off('error', onError);
  }
}
