// End-to-end test of the whole system: Flutter app -> this backend -> test database.
// Creates a throwaway schema in TEST_DATABASE_URL with demo services and counters,
// starts the backend on a free port, runs the Flutter e2e tests against it, then cleans up.
const path = require('node:path');
const { spawn } = require('node:child_process');
const db = require('../test/helpers/testDb');
const { createApp } = require('../src/app');
const { createTicketService } = require('../src/ticket-service');

const FRONTEND_DIR = path.join(__dirname, '..', '..', 'frontend');

async function seed() {
  const shipping = await db.addService('Shipping', 5);
  const deposit = await db.addService('Deposit', 8);
  await db.addCounter('Counter 1', [shipping, deposit]);
  await db.addCounter('Counter 2', [deposit]);
}

function runFlutterTests(apiUrl) {
  return new Promise((resolve) => {
    const flutter = spawn('flutter', ['test', 'test/e2e', `--dart-define=E2E_API_URL=${apiUrl}`], {
      cwd: FRONTEND_DIR,
      stdio: 'inherit',
      shell: process.platform === 'win32', // flutter is a .bat file on Windows
    });
    flutter.once('error', (error) => {
      console.error(`Could not start flutter: ${error.message}`);
      resolve(1);
    });
    flutter.once('exit', code => resolve(code ?? 1));
  });
}

async function main() {
  if (db.skipReason) throw new Error(db.skipReason);

  await db.createSchema();
  let server;
  try {
    await seed();
    server = await new Promise((resolve, reject) => {
      const listener = createApp(createTicketService()).listen(0, '127.0.0.1', () => resolve(listener));
      listener.once('error', reject);
    });
    const apiUrl = `http://127.0.0.1:${server.address().port}`;
    console.log(`E2E backend on ${apiUrl} (schema ${process.env.DB_SCHEMA})`);

    process.exitCode = await runFlutterTests(apiUrl);
  } finally {
    if (server) {
      server.closeAllConnections();
      await new Promise(resolve => server.close(resolve));
    }
    await db.dropSchema();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
