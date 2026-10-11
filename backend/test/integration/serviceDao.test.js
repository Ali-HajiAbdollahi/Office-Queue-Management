const { describe, test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const db = require('../helpers/testDb');
const serviceDao = require('../../src/dao/serviceDao');

describe('serviceDao', { skip: db.skipReason }, () => {
  before(db.createSchema);
  after(db.dropSchema);
  beforeEach(db.resetData);

  test('createService stores the service and trims the tag', async () => {
    const service = await serviceDao.createService('  Shipping ', 5);
    assert.equal(service.tag, 'Shipping');
    assert.equal(service.serviceTime, 5);
    assert.deepEqual(await serviceDao.getService(service.id), service);
  });

  test('two services cannot share the initial of the ticket code', async () => {
    await serviceDao.createService('Shipping', 5);
    await assert.rejects(serviceDao.createService('shopping', 3), /Initial "S" is already used/);
    await assert.rejects(serviceDao.createService('Shipping', 3), /already exists/);
  });

  test('createService validates its input', async () => {
    await assert.rejects(serviceDao.createService('', 5), /tag is required/);
    await assert.rejects(serviceDao.createService('1st desk', 5), /must start with a letter/);
    await assert.rejects(serviceDao.createService('Deposit', 0), /positive integer/);
    await assert.rejects(serviceDao.createService('Deposit', 2.5), /positive integer/);
  });

  test('getServices returns every service ordered by id', async () => {
    await serviceDao.createService('Shipping', 5);
    await serviceDao.createService('Deposit', 8);
    const services = await serviceDao.getServices();
    assert.deepEqual(services.map(s => s.tag), ['Shipping', 'Deposit']);
  });

  test('getService returns null for a missing id', async () => {
    assert.equal(await serviceDao.getService(12345), null);
  });
});
