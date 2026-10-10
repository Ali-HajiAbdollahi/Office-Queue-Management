const ticketRepository = require("../repositories/ticketRespository");

async function callNextTicket(counterId) {
  return ticketRepository.callNextTicket(counterId);
}

async function completeTicket(ticketId) {
  return ticketRepository.completeTicket(ticketId);
}

module.exports = { callNextTicket, completeTicket };
