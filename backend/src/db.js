const { Pool } = require('pg');

function createPool(connectionString = process.env.DATABASE_URL) {

  if (!connectionString) throw new Error('DATABASE_URL is required');

  const pool = new Pool({ connectionString, max: 5, connectionTimeoutMillis: 15000 });

  pool.on('error', error => console.error('Database connection error:', error.code || 'unknown'));

  return pool;

}

module.exports = { createPool };