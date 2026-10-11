const cron = require('node-cron');

 

function startResetJob(service, { timezone, reset_hour }, { scheduler = cron, logger = console } = {}) {

  return scheduler.schedule(`0 ${reset_hour} * * *`, async () => {

    try {

      const result = await service.resetIfNeeded();

      if (result.reset) logger.info('Daily queues reset:', result);

    } catch (error) {

      // Do not crash the API on scheduler failure. The next request or startup

      // retries the same idempotent rollover inside a database transaction.

      logger.error('Daily reset failed:', error);

    }

  }, { timezone, noOverlap: true, name: 'office-daily-reset' });

}

 

module.exports = { startResetJob };