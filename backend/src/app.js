const express = require('express');

const cors = require('cors');

const { HttpError } = require('./errors');

 

function createApp(service, { corsOrigin = 'http://localhost:8080', logger = console } = {}) {

  const app = express();

  app.disable('x-powered-by');

  app.use(cors({ origin: corsOrigin }));

  app.use(express.json({ limit: '16kb' }));

  app.use('/api', (_req, res, next) => {

    res.set('Cache-Control', 'no-store');

    next();

  });

 

  app.get('/api/services', async (_req, res) => res.json({ services: await service.listServices() }));

  app.post('/api/tickets', async (req, res) => {

    if (!req.is('application/json')) throw new HttpError(415, 'Content-Type must be application/json');

    const result = await service.issueTicket(req.body?.serviceId);

    res.status(201).json(result);

  });

  app.use((_req, res) => res.status(404).json({ error: 'Route not found' }));

  app.use((error, _req, res, _next) => {

    if (error.type === 'entity.parse.failed') return res.status(400).json({ error: 'Invalid JSON' });

    if (error.type === 'entity.too.large') return res.status(413).json({ error: 'Request body too large' });

    if (error instanceof HttpError) return res.status(error.status).json({ error: { code: error.code, message: error.message } });

    logger.error('Request failed:', error);

    return res.status(500).json({ error: 'Internal server error' });

  });

  return app;

}

 

module.exports = { createApp };