const ticketRepository = require("../repositories/ticketRespository");

async function callNextTicket(counterId) {
  return ticketRepository.callNextTicket(counterId);
}

async function completeTicket(ticketId) {
  return ticketRepository.completeTicket(ticketId);
}

async function listCounters() {
  return ticketRepository.listCounters();
}

module.exports = { callNextTicket, completeTicket, listCounters };
