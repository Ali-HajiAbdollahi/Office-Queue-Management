const { HttpError } = require('./errors');

function validateServiceId(value) {
  if (!Number.isSafeInteger(value) || value < 1 || value > 2147483647) {
    throw new HttpError(400, 'service_id must be a positive integer', 'INVALID_SERVICE_ID');
  }
  return value;
}

module.exports = { validateServiceId };
