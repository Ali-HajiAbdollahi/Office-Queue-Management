const { Pool } = require('pg');

let pool;

// single shared pool: Neon closes idle connections
function getPool() {
  if (!pool) {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) throw new Error('DATABASE_URL is required: copy .env.example to .env');
    // max 5 parallel connections, after 15 seconds without reaching connection -> timeout
    pool = new Pool({ connectionString, max: 5, connectionTimeoutMillis: 15000 });
    pool.on('error', error => console.error('Database connection error:', error.code || 'unknown'));
  }
  return pool;
}

// wrapper function to execute a query
function query(text, params) {
  return getPool().query(text, params);
}

// close connection
async function closePool() {
  if (!pool) return;
  await pool.end();
  pool = undefined;
}

module.exports = { getPool, query, closePool };
