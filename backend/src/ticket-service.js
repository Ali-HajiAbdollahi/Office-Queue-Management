const ticketDao = require('./dao/ticketDao');
const serviceDao = require('./dao/serviceDao');
const { validateServiceId } = require('./validation');
const { HttpError } = require('./errors'); 

const DAO_ERRORS = {
  INVALID_SERVICE_ID: [400, 'service_id must be a positive integer'],
  SERVICE_NOT_FOUND: [404, 'Service not found'],
  SERVICE_TAG_INVALID: [409, 'Service tag must start with a letter'],
  DAILY_LIMIT_REACHED: [409, 'Daily ticket limit reached'],
};

function createTicketService({ tickets = ticketDao, services = serviceDao } = {}) {
  async function issueTicket(serviceId) {
    validateServiceId(serviceId);
    try {
      return await tickets.createTicketWithQueue(serviceId);
    } catch (error) {
      const known = DAO_ERRORS[error.code];
      if (known) throw new HttpError(known[0], known[1], error.code);
      throw error;
    }
  }

 

  async function getTicket(id) {
    const ticket = await tickets.getTicket(id);
    if (!ticket) throw new HttpError(404, 'Ticket not found', 'TICKET_NOT_FOUND');
    return ticket;
  }

  async function getQueues() {
    return { queues: await tickets.getQueues() };

  }

  async function listServices() {
    return services.getServices();
  }

  return { issueTicket, getTicket, getQueues, listServices };

} 

module.exports = { createTicketService };