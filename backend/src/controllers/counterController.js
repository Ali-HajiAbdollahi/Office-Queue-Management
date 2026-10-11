const counterService = require("../services/counterService");

async function callNext(req, res, next) {
  const counterId = Number(req.params.counter_id);

  if (!Number.isInteger(counterId) || counterId <= 0) {
    return res.status(400).json({
      error: "counter_id must be a positive integer",
    });
  }

  try {
    const ticket = await counterService.callNextTicket(counterId);

    if (!ticket) {
      return res.status(404).json({
        message: "No waiting tickets for this counter",
      });
    }

    return res.status(200).json(ticket);
  } catch (error) {
    if (error.code === "COUNTER_NOT_FOUND") {
      return res.status(404).json({ error: "Counter not found" });
    }

    return next(error);
  }
}

async function completeTicket(req, res, next) {
  const ticketId = Number(req.params.ticket_id);

  if (!Number.isInteger(ticketId) || ticketId <= 0) {
    return res.status(400).json({
      error: "ticket_id must be a positive integer",
    });
  }

  try {
    const ticket = await counterService.completeTicket(ticketId);
    return res.status(200).json(ticket);
  } catch (error) {
    if (error.code === "TICKET_NOT_FOUND") {
      return res.status(404).json({ error: "Ticket not found" });
    }

    if (error.code === "TICKET_NOT_CALLED") {
      return res.status(409).json({
        error: "Ticket must be called before it can be completed",
      });
    }

    return next(error);
  }
}

async function getCounters(req, res, next) {
  try {
    const counters = await counterService.listCounters();
    return res.status(200).json(counters);
  } catch (error) {
    return next(error);
  }
}

module.exports = { callNext, completeTicket, getCounters };
