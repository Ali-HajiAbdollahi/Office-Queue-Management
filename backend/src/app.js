const express = require('express');
const cors = require('cors');
const { HttpError } = require('./errors');
const { parseTicketId } = require('./validation');
const counterRoutes = require('./routes/counterRoutes');

function ticketJson(ticket) {
  return {
    id: ticket.id,
    code: ticket.code,
    service_id: ticket.serviceId,
    status: ticket.status,
    issued_at: ticket.issuedAt,
    served_at: ticket.servedAt,
    counter_id: ticket.counterId,
    is_active: ticket.isActive,
  };
}

function createApp(service, { corsOrigin = 'http://localhost:8080', logger = console } = {}) {
  const app = express();

  app.disable('x-powered-by');
  app.use(cors({ origin: corsOrigin }));
  app.use(express.json({ limit: '16kb' }));
  app.use('/api', (_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });

  app.get('/api/health', (_req, res) => res.json({ status: 'ok' }));

  app.get('/api/services', async (_req, res) => {
    const services = await service.listServices();
    res.json(services.map(s => ({
      id: s.id,
      tag: s.tag,
      service_time: s.serviceTime,
    })));
  });

  app.get('/api/queues', async (_req, res) => {
    const { queues } = await service.getQueues();
    res.json({
      queues: queues.map(q => ({
        service_id: q.serviceId,
        tag: q.tag,
        service_time: q.serviceTime,
        queue_length: q.queueLength,
      })),
    });
  });

  app.post('/api/tickets', async (req, res) => {
    if (!req.is('application/json')) {
      throw new HttpError(415, 'Content-Type must be application/json');
    }

    const { ticket, queueLength } = await service.issueTicket(req.body?.service_id);
    res.status(201).json({ ...ticketJson(ticket), queue_length: queueLength });
  });

  app.get('/api/tickets/:ticket_id', async (req, res) => {
    const id = parseTicketId(req.params.ticket_id);
    res.json(ticketJson(await service.getTicket(id)));
  });

  app.use('/api', counterRoutes);

  app.use((_req, res) => res.status(404).json({ error: 'Route not found' }));

  app.use((error, _req, res, _next) => {
    if (error.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'Invalid JSON' });
    }
    if (error.type === 'entity.too.large') {
      return res.status(413).json({ error: 'Request body too large' });
    }
    if (error instanceof HttpError) {
      return res.status(error.status).json({
        error: { code: error.code, message: error.message },
      });
    }

    logger.error('Request failed:', error);
    return res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

module.exports = { createApp };