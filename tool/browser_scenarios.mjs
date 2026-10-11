import assert from 'node:assert/strict';

// Shared assertions for CDP Chrome and Playwright Firefox/WebKit.
export async function checkNavigation({ command, until, evaluate, navigate, reload, base, expectedWasm, exceptions, browser }) {
  await navigate(base);
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
  await reload();
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
  await command('push', '/item/8');
  await until(s => s.title === 'Item /item/8');
  await command('remove');
  state = await until(s => s.selected === -1 && s.title.includes('Item /item/42'));
  assert.equal(state.history.at(-1).action, 'remove');
  assert.equal(state.history.at(-1).from, '/item/8');
  assert.deepEqual(state.stack, ['/', '/item/42?tag=a&tag=b#details']);
  assert.deepEqual(state.inspectionStack, state.stack);
  const restoredIds = state.ids;
  await command('restoreArguments');
  state = await until(s => s.title === 'Restored title');
  assert.deepEqual(state.ids, restoredIds);
  assert.equal(state.arguments.title, 'Restored title');
  const historyLength = await evaluate('history.length');
  await command('replace', '/other');
  state = await until(s => s.title === 'Other /other');
  assert.equal(state.history.at(-1).action, 'replace');
  assert.equal(await evaluate('history.length'), historyLength);
  await command('go', '/redirect');
  state = await until(s => s.uri === '/other' && s.title === 'Other /other');
  assert.equal(state.history.at(-1).action, 'redirect');
  assert.equal(state.history.at(-1).from, '/redirect');
  await navigate(base + '#/item/99?tag=deep');
  state = await until(s => s.uri === '/item/99?tag=deep' && s.title.includes('Item /item/99'));
  assert.deepEqual(state.stack, ['/', '/item/99?tag=deep']);
  await reload();
  state = await until(s => s.uri === '/item/99?tag=deep' && s.title.includes('Item /item/99'));
  assert.equal(state.selected, -1);
  await command('pushRoute', '101');
  state = await until(s => s.title === 'Item /item/101');
  const beforeRefresh = state.ids;
  await command('refresh');
  state = await until(s => s.history.at(-1).action === 'refresh');
  assert.deepEqual(state.ids, beforeRefresh);
  assert.equal(state.title, 'Item /item/101');
  await command('pop');
  state = await until(s => s.selected === 42 && s.uri === '/item/99?tag=deep');
  assert.deepEqual(state.errors, []);
  assert.ok(state.history.length <= 32);
  assert.deepEqual(exceptions, []);
  console.log(JSON.stringify({
    mode: expectedWasm ? 'wasm' : 'javascript', browser,
    passed: ['push', 'URL', 'title', 'back', 'forward', 'identity', 'arguments', 'reload', 'typed pop', 'remove', 'restored title', 'replace', 'redirect', 'direct entry', 'current route', 'stack snapshots', 'event history', 'redacted diagnostics', 'typed definition push', 'refresh identity'], state
  }, null, 2));
}
