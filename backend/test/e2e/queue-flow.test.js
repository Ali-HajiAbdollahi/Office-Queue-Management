const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const db = require('../helpers/testDb');
const { request } = require('../helpers/http');

function freePort() {
  return new Promise((resolve, reject) => {
    const probe = net.createServer();
    probe.once('error', reject);
    probe.listen(0, '127.0.0.1', () => {
      const { port } = probe.address();
      probe.close(() => resolve(port));
    });
  });
}

// starts the real backend (src/server.js) as a separate process and waits until it listens
async function startServer() {
  const port = await freePort();
  const child = spawn(process.execPath, ['src/server.js'], {
    cwd: path.join(__dirname, '..', '..'),
    env: { ...process.env, PORT: String(port) },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  let output = '';
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Server did not start:\n${output}`)), 20000);
    child.stdout.on('data', chunk => {
      output += chunk;
      if (output.includes('listening on port')) { clearTimeout(timer); resolve(); }
    });
    child.stderr.on('data', chunk => { output += chunk; });
    child.once('exit', code => { clearTimeout(timer); reject(new Error(`Server exited (${code}):\n${output}`)); });
  });
  return { url: `http://127.0.0.1:${port}/api`, child };
}

describe('e2e: a customer gets a ticket and an officer calls it', { skip: db.skipReason }, () => {
  let server;
  let shipping;
  let deposit;
  let counter1;
  let counter2;
  const tickets = {};

  before(async () => {
    await db.createSchema();
    shipping = await db.addService('Shipping', 5);
    deposit = await db.addService('Deposit', 8);
    counter1 = await db.addCounter('Counter 1', [shipping, deposit]);
    counter2 = await db.addCounter('Counter 2', [deposit]);
    server = await startServer();
  });

  after(async () => {
    server?.child.kill();
    await db.dropSchema();
  });

  test('the server is up', async () => {
    const res = await request(`${server.url}/health`);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { status: 'ok' });
  });

  test('the customer sees the services', async () => {
    const res = await request(`${server.url}/services`);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, [
      { id: shipping, tag: 'Shipping', service_time: 5 },
      { id: deposit, tag: 'Deposit', service_time: 8 },
    ]);
  });

  test('customers get tickets with progressive codes per service', async () => {
    for (const [name, serviceId, code, queueLength] of [
      ['d1', deposit, 'D-0001', 1],
      ['d2', deposit, 'D-0002', 2],
      ['s1', shipping, 'S-0001', 1],
    ]) {
      const res = await request(`${server.url}/tickets`, { method: 'POST', body: { service_id: serviceId } });
      assert.equal(res.status, 201);
      assert.equal(res.body.code, code);
      assert.equal(res.body.status, 'waiting');
      assert.equal(res.body.queue_length, queueLength);
      tickets[name] = res.body;
    }
  });

  test('a ticket for a missing service is refused', async () => {
    const res = await request(`${server.url}/tickets`, { method: 'POST', body: { service_id: 9999 } });
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, 'SERVICE_NOT_FOUND');
  });

  test('the queues show how many people are waiting', async () => {
    const res = await request(`${server.url}/queues`);
    assert.deepEqual(res.body.queues.map(q => [q.tag, q.queue_length]), [['Shipping', 1], ['Deposit', 2]]);
  });

  test('the officer sees the counters', async () => {
    const res = await request(`${server.url}/counters`);
    assert.deepEqual(res.body, [{ id: counter1, name: 'Counter 1' }, { id: counter2, name: 'Counter 2' }]);
  });

  test('Counter 1 calls the first ticket of the longest queue', async () => {
    const res = await request(`${server.url}/counters/${counter1}/call-next`, { method: 'POST' });
    assert.equal(res.status, 200);
    assert.equal(res.body.code, 'D-0001');
    assert.equal(res.body.status, 'called');
    assert.equal(res.body.counter_id, counter1);
  });

  test('the customer sees the ticket called to Counter 1', async () => {
    const res = await request(`${server.url}/tickets/${tickets.d1.id}`);
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'called');
    assert.equal(res.body.counter_id, counter1);
    assert.equal(res.body.is_active, false);
  });

  test('the called ticket left its queue', async () => {
    const res = await request(`${server.url}/queues`);
    assert.deepEqual(res.body.queues.map(q => [q.tag, q.queue_length]), [['Shipping', 1], ['Deposit', 1]]);
  });

  test('with queues of equal length Counter 1 serves the faster service', async () => {
    const res = await request(`${server.url}/counters/${counter1}/call-next`, { method: 'POST' });
    assert.equal(res.body.code, 'S-0001');
  });

  test('Counter 2 serves the last Deposit ticket, then finds nothing', async () => {
    const res = await request(`${server.url}/counters/${counter2}/call-next`, { method: 'POST' });
    assert.equal(res.body.code, 'D-0002');
    const empty = await request(`${server.url}/counters/${counter2}/call-next`, { method: 'POST' });
    assert.equal(empty.status, 404);
  });

  test('the officer completes a called ticket only once', async () => {
    const done = await request(`${server.url}/tickets/${tickets.d1.id}/complete`, { method: 'PUT' });
    assert.equal(done.status, 200);
    assert.equal(done.body.status, 'completed');
    const again = await request(`${server.url}/tickets/${tickets.d1.id}/complete`, { method: 'PUT' });
    assert.equal(again.status, 409);
  });

  test('calling from a missing counter returns 404', async () => {
    const res = await request(`${server.url}/counters/9999/call-next`, { method: 'POST' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, 'COUNTER_NOT_FOUND');
  });

});
