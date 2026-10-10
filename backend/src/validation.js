const { HttpError } = require('./errors');

const MAX_DAILY_TICKETS = 9999;

function validateServiceId(value) {

  if (!Number.isSafeInteger(value) || value < 1 || value > 2147483647) {

    throw new HttpError(400, 'serviceId must be a positive integer', 'INVALID_SERVICE_ID');

  }

  return value;

}

function formatTicketCode(prefix, number) {

  if (!/^[A-Z]$/.test(prefix || '')) {

    throw new HttpError(409, 'Service ticket prefix is not configured', 'SERVICE_PREFIX_NOT_CONFIGURED');

  }

  if (!Number.isInteger(number) || number < 1 || number > MAX_DAILY_TICKETS) {

    throw new HttpError(409, 'Daily ticket limit reached', 'DAILY_TICKET_LIMIT_REACHED');

  }

  return `${prefix}-${String(number).padStart(4, '0')}`;

}

module.exports = { validateServiceId, formatTicketCode, MAX_DAILY_TICKETS };