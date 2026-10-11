const { Pool } = require('pg');

let pool;

// Creates an independent pool.
// Used by the ticket backend and by tests with a separate database.
function createPool(connectionString = process.env.DATABASE_URL) {
  if (!connectionString) {
    throw new Error(
      'DATABASE_URL is required: copy .env.example to .env'
    );
  }

  const newPool = new Pool({
    connectionString,
    max: 5,
    connectionTimeoutMillis: 15000,
  });

  newPool.on('error', error => {
    console.error(
      'Database connection error:',
      error.code || 'unknown'
    );
  });

  return newPool;
}

// Returns the shared pool, creating it when first needed.
function getPool() {
  if (!pool) {
    pool = createPool();
  }

  return pool;
}

// Executes a query using the shared pool.
function query(text, params) {
  return getPool().query(text, params);
}

// Closes the shared pool.
async function closePool() {
  if (!pool) return;

  await pool.end();
  pool = undefined;
}

module.exports = {
  createPool,
  getPool,
  query,
  closePool,
};