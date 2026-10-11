const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const { createTicketService } = require('../../src/ticket-service');
const { HttpError } = require('../../src/errors');

function daoError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
}

// fake DAOs: every call is recorded so the tests can check what the service asked for
function fakeDaos(overrides = {}) {
  const calls = [];
  const tickets = {
    createTicketWithQueue: async (serviceId) => {
      calls.push(['createTicketWithQueue', serviceId]);
      return { ticket: { id: 1, code: 'S-0001', serviceId }, queueLength: 1 };
    },
    getTicket: async (id) => ({ id, code: 'S-0001' }),
    getQueues: async () => [{ serviceId: 1, tag: 'Shipping', serviceTime: 5, queueLength: 2 }],
    ...overrides.tickets,
  };
  const services = {
    getServices: async () => [{ id: 1, tag: 'Shipping', serviceTime: 5 }],
    ...overrides.services,
  };
  return { calls, service: createTicketService({ tickets, services }) };
}

describe('ticket service', () => {
  describe('issueTicket', () => {
    test('returns the ticket and the queue length from the DAO', async () => {
      const { service, calls } = fakeDaos();
      const result = await service.issueTicket(1);
      assert.deepEqual(result, { ticket: { id: 1, code: 'S-0001', serviceId: 1 }, queueLength: 1 });
      assert.deepEqual(calls, [['createTicketWithQueue', 1]]);
    });

    test('rejects an invalid service id without touching the DAO', async () => {
      const { service, calls } = fakeDaos();
      for (const value of [undefined, '1', 0, -3, 1.5]) {
        await assert.rejects(service.issueTicket(value), { status: 400, code: 'INVALID_SERVICE_ID' });
      }
      assert.deepEqual(calls, []);
    });

    const mapped = [
      ['SERVICE_NOT_FOUND', 404],
      ['SERVICE_TAG_INVALID', 409],
      ['DAILY_LIMIT_REACHED', 409],
      ['INVALID_SERVICE_ID', 400],
    ];
    for (const [code, status] of mapped) {
      test(`maps the DAO error ${code} to HTTP ${status}`, async () => {
        const { service } = fakeDaos({ tickets: { createTicketWithQueue: async () => { throw daoError(code); } } });
        await assert.rejects(service.issueTicket(1), (error) => {
          assert.ok(error instanceof HttpError);
          assert.equal(error.status, status);
          assert.equal(error.code, code);
          return true;
        });
      });
    }

    test('rethrows unknown errors unchanged', async () => {
      const original = new Error('connection lost');
      const { service } = fakeDaos({ tickets: { createTicketWithQueue: async () => { throw original; } } });
      await assert.rejects(service.issueTicket(1), (error) => error === original);
    });
  });

  describe('getTicket', () => {
    test('returns the ticket', async () => {
      const { service } = fakeDaos();
      assert.deepEqual(await service.getTicket(7), { id: 7, code: 'S-0001' });
    });

    test('throws 404 TICKET_NOT_FOUND when the DAO returns null', async () => {
      const { service } = fakeDaos({ tickets: { getTicket: async () => null } });
      await assert.rejects(service.getTicket(7), { status: 404, code: 'TICKET_NOT_FOUND' });
    });
  });

  test('getQueues wraps the queues of the DAO', async () => {
    const { service } = fakeDaos();
    assert.deepEqual(await service.getQueues(), {
      queues: [{ serviceId: 1, tag: 'Shipping', serviceTime: 5, queueLength: 2 }],
    });
  });

  test('listServices returns the services of the DAO', async () => {
    const { service } = fakeDaos();
    assert.deepEqual(await service.listServices(), [{ id: 1, tag: 'Shipping', serviceTime: 5 }]);
  });
});
