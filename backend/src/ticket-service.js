const ticketDao = require('./dao/ticketDao');
const serviceDao = require('./dao/serviceDao');
const { validateServiceId } = require('./validation');
const { HttpError } = require('./errors');

// codes raised by the DAOs -> HTTP errors
const DAO_ERRORS = {
  SERVICE_NOT_FOUND: [404, 'Service not found'],
  SERVICE_TAG_INVALID: [409, 'Service tag must start with a letter'],
  DAILY_LIMIT_REACHED: [409, 'Daily ticket limit reached'],
};

function toHttpError(error) {
  const known = DAO_ERRORS[error.code];
  return known ? new HttpError(known[0], known[1], error.code) : error;
}

function createTicketService({ tickets = ticketDao, services = serviceDao } = {}) {
  async function issueTicket(serviceId) {
    validateServiceId(serviceId);
    try {
      const ticket = await tickets.createTicket(serviceId);
      const queueLength = await tickets.getQueueLength(serviceId);
      return { ticket, queueLength };
    } catch (error) {
      throw toHttpError(error);
    }
  }

  async function getQueues() {
    return { queues: await tickets.getQueues() };
  }

  async function listServices() {
    return services.getServices();
  }

  return { issueTicket, getQueues, listServices };
}

module.exports = { createTicketService };
