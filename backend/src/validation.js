const { HttpError } = require('./errors');

 

function validateServiceId(value) {

  if (!Number.isSafeInteger(value) || value < 1 || value > 2147483647) {
    throw new HttpError(400, 'service_id must be a positive integer', 'INVALID_SERVICE_ID');
  }
  return value;

}

function parseTicketId(value) {
  if (typeof value !== 'string' || !/^[1-9][0-9]*$/.test(value)) {
    throw new HttpError(400, 'ticket_id must be a positive integer', 'INVALID_TICKET_ID');
  }

  const id = Number(value);
  if (!Number.isSafeInteger(id) || id > 2147483647) {
    throw new HttpError(400, 'ticket_id is out of range', 'INVALID_TICKET_ID');
  }
  return id;

}

module.exports = { validateServiceId, parseTicketId };