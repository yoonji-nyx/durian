const test = require('node:test');
const assert = require('node:assert');
const { handler } = require('./index');

function call(url) {
  return new Promise((resolve) => {
    const res = {
      status: 0,
      body: '',
      writeHead(s) { this.status = s; },
      end(b) { this.body = b; resolve(this); },
    };
    handler({ url }, res);
  });
}

test('/health returns ok', async () => {
  const r = await call('/health');
  assert.strictEqual(r.status, 200);
  assert.deepStrictEqual(JSON.parse(r.body), { status: 'ok' });
});

test('/ returns greeting', async () => {
  const r = await call('/');
  assert.strictEqual(r.status, 200);
  assert.match(r.body, /hello/);
});
