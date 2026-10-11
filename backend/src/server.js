const { getPool, closePool } = require('./db');
const { createApp } = require('./app');
const { createTicketService } = require('./ticket-service');

async function main() {
  const port = Number(process.env.PORT || 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');

  try {
    await getPool().query('SELECT 1'); // fail fast if the database is not reachable
    const app = createApp(createTicketService(), {
      corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:8080',
    });
    const server = await new Promise((resolve, reject) => {
      const listener = app.listen(port, () => resolve(listener));
      listener.once('error', reject);
    });
    console.log(`Office Queue API listening on port ${port}`);

    let stopping = false;
    function shutdown() {
      if (stopping) return;
      stopping = true;
      server.close(async () => { await closePool(); });
    }
    process.once('SIGINT', shutdown);
    process.once('SIGTERM', shutdown);
  } catch (error) {
    await closePool();
    throw error;
  }
}

if (require.main === module) main().catch((error) => {
  console.error('Startup failed:', error.message);
  process.exitCode = 1;
});

module.exports = { main };
