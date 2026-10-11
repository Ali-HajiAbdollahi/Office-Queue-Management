const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const { validateServiceId, parseTicketId } = require('../../src/validation');
const { HttpError } = require('../../src/errors');

const invalidServiceId = { status: 400, code: 'INVALID_SERVICE_ID' };
const invalidTicketId = { status: 400, code: 'INVALID_TICKET_ID' };

describe('validateServiceId', () => {
  test('accepts positive integers and returns them', () => {
    assert.equal(validateServiceId(1), 1);
    assert.equal(validateServiceId(2147483647), 2147483647);
  });

  for (const value of [0, -1, 1.5, '1', null, undefined, NaN, 2147483648, Number.MAX_SAFE_INTEGER + 1]) {
    test(`rejects ${String(value)} (${typeof value})`, () => {
      assert.throws(() => validateServiceId(value), invalidServiceId);
    });
  }

  test('throws an HttpError', () => {
    assert.throws(() => validateServiceId('x'), HttpError);
  });
});

describe('parseTicketId', () => {
  test('parses a numeric string', () => {
    assert.equal(parseTicketId('42'), 42);
    assert.equal(parseTicketId('2147483647'), 2147483647);
  });

  for (const value of ['0', '-1', '01', '1.5', 'abc', '', ' 1', '1e3', 42, undefined]) {
    test(`rejects ${JSON.stringify(value)}`, () => {
      assert.throws(() => parseTicketId(value), invalidTicketId);
    });
  }

  test('rejects ids outside the integer column range', () => {
    assert.throws(() => parseTicketId('2147483648'), invalidTicketId);
    assert.throws(() => parseTicketId('99999999999999999999'), invalidTicketId);
  });
});
