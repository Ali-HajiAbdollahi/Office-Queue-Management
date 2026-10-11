const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../../src/app');
const { HttpError } = require('../../src/errors');
const counterService = require('../../src/services/counterService');
const { listen, request } = require('../helpers/http');

const ticket = {
  id: 10, code: 'S-0003', serviceId: 1, status: 'waiting',
  issuedAt: '2026-10-11T08:00:00.000Z', servedAt: null, counterId: null, isActive: true,
};

// fake ticket service: each test can replace a method through `behaviour`
const behaviour = {};
const fakeService = {
  issueTicket: (...args) => behaviour.issueTicket(...args),
  getTicket: (...args) => behaviour.getTicket(...args),
  getQueues: async () => ({ queues: [{ serviceId: 1, tag: 'Shipping', serviceTime: 5, queueLength: 3 }] }),
  listServices: async () => [{ id: 1, tag: 'Shipping', serviceTime: 5 }],
};

const loggedErrors = [];
let server;

before(async () => {
  server = await listen(createApp(fakeService, { logger: { error: (...args) => loggedErrors.push(args) } }));
});
after(() => server.close());

describe('customer routes', () => {
  test('GET /api/services answers in snake_case', async () => {
    const res = await request(`${server.url}/api/services`);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, [{ id: 1, tag: 'Shipping', service_time: 5 }]);
  });

  test('every /api response disables caching', async () => {
    const res = await request(`${server.url}/api/services`);
    assert.equal(res.headers.get('cache-control'), 'no-store');
  });

  test('GET /api/queues answers in snake_case', async () => {
    const res = await request(`${server.url}/api/queues`);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { queues: [{ service_id: 1, tag: 'Shipping', service_time: 5, queue_length: 3 }] });
  });

  test('POST /api/tickets returns 201 with the ticket and the queue length', async () => {
    let received;
    behaviour.issueTicket = async (serviceId) => { received = serviceId; return { ticket, queueLength: 3 }; };
    const res = await request(`${server.url}/api/tickets`, { method: 'POST', body: { service_id: 1 } });
    assert.equal(res.status, 201);
    assert.equal(received, 1);
    assert.deepEqual(res.body, {
      id: 10, code: 'S-0003', service_id: 1, status: 'waiting',
      issued_at: '2026-10-11T08:00:00.000Z', served_at: null, counter_id: null,
      is_active: true, queue_length: 3,
    });
  });

  test('POST /api/tickets without a JSON body returns 415', async () => {
    const res = await request(`${server.url}/api/tickets`, {
      method: 'POST', body: 'service_id=1', headers: { 'Content-Type': 'text/plain' },
    });
    assert.equal(res.status, 415);
  });

  test('POST /api/tickets with malformed JSON returns 400', async () => {
    const res = await request(`${server.url}/api/tickets`, { method: 'POST', body: '{"service_id": ' });
    assert.equal(res.status, 400);
    assert.deepEqual(res.body, { error: 'Invalid JSON' });
  });

  test('an HttpError of the service becomes { error: { code, message } }', async () => {
    behaviour.issueTicket = async () => { throw new HttpError(404, 'Service not found', 'SERVICE_NOT_FOUND'); };
    const res = await request(`${server.url}/api/tickets`, { method: 'POST', body: { service_id: 99 } });
    assert.equal(res.status, 404);
    assert.deepEqual(res.body, { error: { code: 'SERVICE_NOT_FOUND', message: 'Service not found' } });
  });

  test('an unexpected error returns 500 without leaking details, and is logged', async () => {
    loggedErrors.length = 0;
    behaviour.issueTicket = async () => { throw new Error('password authentication failed'); };
    const res = await request(`${server.url}/api/tickets`, { method: 'POST', body: { service_id: 1 } });
    assert.equal(res.status, 500);
    assert.deepEqual(res.body, { error: 'Internal server error' });
    assert.equal(loggedErrors.length, 1);
  });

  test('GET /api/tickets/:id returns the ticket', async () => {
    let received;
    behaviour.getTicket = async (id) => { received = id; return { ...ticket, isActive: false }; };
    const res = await request(`${server.url}/api/tickets/10`);
    assert.equal(res.status, 200);
    assert.equal(received, 10);
    assert.equal(res.body.code, 'S-0003');
    assert.equal(res.body.is_active, false);
  });

  test('GET /api/tickets/:id with a non numeric id returns 400', async () => {
    const res = await request(`${server.url}/api/tickets/abc`);
    assert.equal(res.status, 400);
    assert.equal(res.body.error.code, 'INVALID_TICKET_ID');
  });

  test('an unknown route returns 404', async () => {
    const res = await request(`${server.url}/api/nothing`);
    assert.equal(res.status, 404);
  });
});

describe('counter routes', () => {
  test('GET /api/counters lists the counters', async (t) => {
    t.mock.method(counterService, 'listCounters', async () => [{ id: 1, name: 'Counter 1' }]);
    const res = await request(`${server.url}/api/counters`);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, [{ id: 1, name: 'Counter 1' }]);
  });

  test('POST /api/counters/:id/call-next returns the called ticket', async (t) => {
    const called = { id: 3, code: 'D-0001', status: 'called', counter_id: 2 };
    const mock = t.mock.method(counterService, 'callNextTicket', async () => called);
    const res = await request(`${server.url}/api/counters/2/call-next`, { method: 'POST' });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, called);
    assert.deepEqual(mock.mock.calls[0].arguments, [2]);
  });

  test('call-next with an invalid counter id returns 400 without calling the service', async (t) => {
    const mock = t.mock.method(counterService, 'callNextTicket', async () => null);
    for (const id of ['abc', '0', '-1', '1.5']) {
      const res = await request(`${server.url}/api/counters/${id}/call-next`, { method: 'POST' });
      assert.equal(res.status, 400, `counter id ${id}`);
    }
    assert.equal(mock.mock.callCount(), 0);
  });

  test('call-next with all queues empty returns 404', async (t) => {
    t.mock.method(counterService, 'callNextTicket', async () => null);
    const res = await request(`${server.url}/api/counters/1/call-next`, { method: 'POST' });
    assert.equal(res.status, 404);
  });

  test('call-next on a missing counter returns 404 COUNTER_NOT_FOUND', async (t) => {
    t.mock.method(counterService, 'callNextTicket', async () => {
      throw Object.assign(new Error('Counter not found'), { code: 'COUNTER_NOT_FOUND' });
    });
    const res = await request(`${server.url}/api/counters/99/call-next`, { method: 'POST' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, 'COUNTER_NOT_FOUND');
  });

  test('PUT /api/tickets/:id/complete maps TICKET_NOT_CALLED to 409', async (t) => {
    t.mock.method(counterService, 'completeTicket', async () => {
      throw Object.assign(new Error('not called'), { code: 'TICKET_NOT_CALLED' });
    });
    const res = await request(`${server.url}/api/tickets/5/complete`, { method: 'PUT' });
    assert.equal(res.status, 409);
    assert.equal(res.body.error.code, 'TICKET_NOT_CALLED');
  });

  test('PUT /api/tickets/:id/complete maps TICKET_NOT_FOUND to 404', async (t) => {
    t.mock.method(counterService, 'completeTicket', async () => {
      throw Object.assign(new Error('missing'), { code: 'TICKET_NOT_FOUND' });
    });
    const res = await request(`${server.url}/api/tickets/5/complete`, { method: 'PUT' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error.code, 'TICKET_NOT_FOUND');
  });
});
