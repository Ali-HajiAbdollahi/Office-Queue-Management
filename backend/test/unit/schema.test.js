const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const { quoteIdentifier, tableNames } = require('../../src/schema');

describe('schema', () => {
  test('tableNames qualifies every table with the given schema', () => {
    assert.deepEqual(tableNames('schema_OQM'), {
      services: '"schema_OQM"."services"',
      tickets: '"schema_OQM"."tickets"',
      counters: '"schema_OQM"."counters"',
      counter_services: '"schema_OQM"."counter_services"',
    });
  });

  test('quoteIdentifier rejects names that could inject SQL', () => {
    for (const name of ['', '1abc', 'a-b', 'a"b', 'a; DROP TABLE x', 'a.b']) {
      assert.throws(() => quoteIdentifier(name), /Invalid DB_SCHEMA/);
    }
  });
});
