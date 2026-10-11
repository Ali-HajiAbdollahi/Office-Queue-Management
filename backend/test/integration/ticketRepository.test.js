const { describe, test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const db = require('../helpers/testDb');
const repository = require('../../src/repositories/ticketRespository');
const ticketDao = require('../../src/dao/ticketDao');

describe('ticketRepository (Next customer)', { skip: db.skipReason }, () => {
  let shipping;
  let deposit;
  let accounts;

  before(db.createSchema);
  after(db.dropSchema);
  beforeEach(async () => {
    await db.resetData();
    shipping = await db.addService('Shipping', 5);
    deposit = await db.addService('Deposit', 8);
    accounts = await db.addService('Accounts', 10);
  });

  async function issue(serviceId, times = 1) {
    const tickets = [];
    for (let i = 0; i < times; i++) tickets.push((await ticketDao.createTicketWithQueue(serviceId)).ticket);
    return tickets;
  }

  describe('callNextTicket', () => {
    test('a missing counter is rejected with COUNTER_NOT_FOUND', async () => {
      await assert.rejects(repository.callNextTicket(9999), { code: 'COUNTER_NOT_FOUND' });
    });

    test('with all its queues empty the counter gets nothing and nothing changes', async () => {
      const counter = await db.addCounter('Counter 1', [shipping]);
      const [other] = await issue(deposit);
      assert.equal(await repository.callNextTicket(counter), null);
      assert.equal((await db.getTicketRow(other.id)).status, 'waiting');
    });

    test('a counter without services gets nothing', async () => {
      const counter = await db.addCounter('Counter 1');
      await issue(shipping);
      assert.equal(await repository.callNextTicket(counter), null);
    });

    test('the called ticket is assigned to the counter and leaves the queue', async () => {
      const counter = await db.addCounter('Counter 1', [shipping]);
      const [first] = await issue(shipping, 2);

      const called = await repository.callNextTicket(counter);
      assert.equal(called.id, first.id);
      assert.equal(called.code, 'S-0001');
      assert.equal(called.status, 'called');
      assert.equal(called.counter_id, counter);
      assert.ok(called.served_at instanceof Date);
      assert.equal(await ticketDao.getQueueLength(shipping), 1);
    });

    test('tickets of the same queue are called in arrival order', async () => {
      const counter = await db.addCounter('Counter 1', [shipping]);
      await issue(shipping, 3);
      const codes = [];
      for (let i = 0; i < 3; i++) codes.push((await repository.callNextTicket(counter)).code);
      assert.deepEqual(codes, ['S-0001', 'S-0002', 'S-0003']);
      assert.equal(await repository.callNextTicket(counter), null);
    });

    test('the longest queue among the counter\'s services is served first', async () => {
      const counter = await db.addCounter('Counter 1', [shipping, deposit]);
      await issue(shipping, 1);
      await issue(deposit, 3);
      assert.equal((await repository.callNextTicket(counter)).service_id, deposit);
    });

    test('with queues of the same length, the lowest service time wins', async () => {
      const counter = await db.addCounter('Counter 1', [deposit, accounts, shipping]);
      await issue(accounts, 2);
      await issue(deposit, 2);
      await issue(shipping, 2);
      assert.equal((await repository.callNextTicket(counter)).service_id, shipping, 'Shipping has 5 minutes');
    });

    test('queues of services the counter cannot handle are ignored', async () => {
      const counter = await db.addCounter('Counter 1', [shipping]);
      await issue(shipping, 1);
      await issue(deposit, 5);
      assert.equal((await repository.callNextTicket(counter)).service_id, shipping);
    });

    test('waiting tickets of previous days are never called', async () => {
      const counter = await db.addCounter('Counter 1', [shipping, deposit]);
      await db.addTicket(deposit, 'D-0001', { daysAgo: 2 });
      await db.addTicket(deposit, 'D-0002', { daysAgo: 2 });
      await issue(shipping, 1);

      const called = await repository.callNextTicket(counter);
      assert.equal(called.service_id, shipping, 'yesterday\'s Deposit queue must not count as longer');
      assert.equal(await repository.callNextTicket(counter), null);
    });

    test('in the same queue, a ticket left waiting yesterday is skipped for today\'s first one', async () => {
      const counter = await db.addCounter('Counter 1', [shipping]);
      const old = await db.addTicket(shipping, 'S-0003', { daysAgo: 2 });
      const [today] = await issue(shipping);

      const called = await repository.callNextTicket(counter);
      assert.equal(called.id, today.id);
      assert.equal((await db.getTicketRow(old)).status, 'waiting', 'the old ticket is left untouched');
      assert.equal(await repository.callNextTicket(counter), null);
    });

    test('two counters calling at the same time never get the same ticket', async () => {
      const counter1 = await db.addCounter('Counter 1', [deposit]);
      const counter2 = await db.addCounter('Counter 2', [deposit]);
      await issue(deposit, 2);

      const [a, b] = await Promise.all([repository.callNextTicket(counter1), repository.callNextTicket(counter2)]);
      assert.ok(a && b, 'both counters get a ticket');
      assert.notEqual(a.id, b.id);
      assert.equal(await ticketDao.getQueueLength(deposit), 0);
    });

    test('example of the specification: both counters serve the shared queue', async () => {
      // Counter 1 serves only Deposit, Counter 2 serves Deposit or Shipping
      const counter1 = await db.addCounter('Counter 1', [deposit]);
      const counter2 = await db.addCounter('Counter 2', [deposit, shipping]);
      await issue(deposit, 4);
      await issue(shipping, 1);

      assert.equal((await repository.callNextTicket(counter2)).code, 'D-0001');
      assert.equal((await repository.callNextTicket(counter1)).code, 'D-0002');
      assert.equal((await repository.callNextTicket(counter2)).code, 'D-0003');
      // now Deposit 1, Shipping 1: same length, Shipping is faster
      assert.equal((await repository.callNextTicket(counter2)).code, 'S-0001');
      assert.equal((await repository.callNextTicket(counter1)).code, 'D-0004');
      assert.equal(await repository.callNextTicket(counter1), null);
    });
  });

  describe('completeTicket', () => {
    test('completes a called ticket', async () => {
      const counter = await db.addCounter('Counter 1', [shipping]);
      await issue(shipping);
      const called = await repository.callNextTicket(counter);
      const completed = await repository.completeTicket(called.id);
      assert.equal(completed.status, 'completed');
      assert.equal(completed.counter_id, counter);
    });

    test('a waiting ticket cannot be completed', async () => {
      const [ticket] = await issue(shipping);
      await assert.rejects(repository.completeTicket(ticket.id), { code: 'TICKET_NOT_CALLED' });
    });

    test('a missing ticket is rejected with TICKET_NOT_FOUND', async () => {
      await assert.rejects(repository.completeTicket(123456), { code: 'TICKET_NOT_FOUND' });
    });
  });

  test('listCounters returns the counters ordered by id', async () => {
    await db.addCounter('Counter 1');
    await db.addCounter('Counter 2');
    assert.deepEqual(await repository.listCounters(), [
      { id: 1, name: 'Counter 1' },
      { id: 2, name: 'Counter 2' },
    ]);
  });
});
