const { describe, test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const db = require('../helpers/testDb');
const ticketDao = require('../../src/dao/ticketDao');

describe('ticketDao (Get ticket)', { skip: db.skipReason }, () => {
  let shipping;
  let deposit;

  before(db.createSchema);
  after(db.dropSchema);
  beforeEach(async () => {
    await db.resetData();
    shipping = await db.addService('Shipping', 5);
    deposit = await db.addService('Deposit', 8);
  });

  test('the first ticket of the day is <initial>-0001, waiting, in a queue of 1', async () => {
    const { ticket, queueLength } = await ticketDao.createTicketWithQueue(shipping);
    assert.equal(ticket.code, 'S-0001');
    assert.equal(ticket.serviceId, shipping);
    assert.equal(ticket.status, 'waiting');
    assert.equal(ticket.counterId, null);
    assert.equal(ticket.servedAt, null);
    assert.equal(ticket.isActive, true);
    assert.ok(ticket.issuedAt instanceof Date);
    assert.equal(queueLength, 1);
  });

  test('numbers are progressive per service', async () => {
    const codes = [];
    for (const serviceId of [shipping, shipping, deposit, shipping]) {
      codes.push((await ticketDao.createTicketWithQueue(serviceId)).ticket.code);
    }
    assert.deepEqual(codes, ['S-0001', 'S-0002', 'D-0001', 'S-0003']);
    assert.equal(await ticketDao.getQueueLength(shipping), 3);
    assert.equal(await ticketDao.getQueueLength(deposit), 1);
  });

  test('numbering restarts every day (queues are reset)', async () => {
    await db.addTicket(shipping, 'S-0007', { daysAgo: 2 });
    const { ticket, queueLength } = await ticketDao.createTicketWithQueue(shipping);
    assert.equal(ticket.code, 'S-0001');
    assert.equal(queueLength, 1, 'tickets of previous days are not in the queue');
  });

  test('tickets already called do not count in the queue', async () => {
    await ticketDao.createTicketWithQueue(shipping);
    await db.addTicket(shipping, 'S-0002', { status: 'called' });
    const { ticket, queueLength } = await ticketDao.createTicketWithQueue(shipping);
    assert.equal(ticket.code, 'S-0003', 'called tickets still use their number');
    assert.equal(queueLength, 2);
  });

  test('concurrent requests never get the same code', async () => {
    const results = await Promise.all(
      Array.from({ length: 10 }, () => ticketDao.createTicketWithQueue(shipping))
    );
    const codes = results.map(r => r.ticket.code).sort();
    assert.deepEqual(codes, Array.from({ length: 10 }, (_, i) => `S-${String(i + 1).padStart(4, '0')}`));
  });

  test('a missing service is rejected with SERVICE_NOT_FOUND', async () => {
    await assert.rejects(ticketDao.createTicketWithQueue(9999), { code: 'SERVICE_NOT_FOUND' });
  });

  test('an invalid service id is rejected with INVALID_SERVICE_ID', async () => {
    await assert.rejects(ticketDao.createTicketWithQueue('1'), { code: 'INVALID_SERVICE_ID' });
    await assert.rejects(ticketDao.createTicketWithQueue(0), { code: 'INVALID_SERVICE_ID' });
  });

  test('after 9999 tickets in a day the service is closed (DAILY_LIMIT_REACHED)', async () => {
    await db.addTicket(shipping, 'S-9999');
    await assert.rejects(ticketDao.createTicketWithQueue(shipping), { code: 'DAILY_LIMIT_REACHED' });
  });

  test('getTicket returns the ticket, isActive only while waiting today', async () => {
    const { ticket } = await ticketDao.createTicketWithQueue(shipping);
    const old = await db.addTicket(shipping, 'S-0004', { daysAgo: 2 });
    const called = await db.addTicket(shipping, 'S-0002', { status: 'called' });

    assert.equal((await ticketDao.getTicket(ticket.id)).isActive, true);
    assert.equal((await ticketDao.getTicket(old)).isActive, false);
    assert.equal((await ticketDao.getTicket(called)).isActive, false);
    assert.equal(await ticketDao.getTicket(123456), null);
  });

  test('getQueues lists every service with today\'s waiting tickets', async () => {
    await ticketDao.createTicketWithQueue(deposit);
    await ticketDao.createTicketWithQueue(deposit);
    await db.addTicket(shipping, 'S-0001', { daysAgo: 2 });

    assert.deepEqual(await ticketDao.getQueues(), [
      { serviceId: shipping, tag: 'Shipping', serviceTime: 5, queueLength: 0 },
      { serviceId: deposit, tag: 'Deposit', serviceTime: 8, queueLength: 2 },
    ]);
  });
});
