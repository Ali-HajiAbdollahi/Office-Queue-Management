const { createPool } = require('./db');

const { tableNames } = require('./schema');

const { createApp } = require('./app');

const { createTicketService } = require('./ticket-service');

const { startResetJob } = require('./reset-job');

 

async function main() {

  const port = Number(process.env.PORT || 3000);

  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid PORT');

  const pool = createPool();

  let job;

  try {

    const service = createTicketService(pool);

    const { rows: [settings] } = await pool.query(`SELECT timezone, reset_hour FROM ${tableNames().office_state} WHERE singleton = true`);

    if (!settings) throw new Error('Run npm run db:migrate first');

    new Intl.DateTimeFormat('en', { timeZone: settings.timezone }).format();

    await service.resetIfNeeded(); // Recover if the process was offline at 06:00.

    const app = createApp(service, { corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:8080' });

    const server = await new Promise((resolve, reject) => {

      const listener = app.listen(port, () => resolve(listener));

      listener.once('error', reject);

    });

    job = startResetJob(service, settings);

    console.log(`Office Queue API listening on port ${port}`);

    let stopping = false;

    async function shutdown() {

      if (stopping) return;

      stopping = true;

      await job.stop();

      server.close(async () => { await pool.end(); });

    }

    process.once('SIGINT', shutdown);

    process.once('SIGTERM', shutdown);

  } catch (error) {

    if (job) await job.stop();

    await pool.end();

    throw error;

  }

}

 

if (require.main === module) main().catch((error) => {

  console.error('Startup failed:', error.message);

  process.exitCode = 1;

});

module.exports = { main };