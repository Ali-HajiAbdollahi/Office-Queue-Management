const { query, getPool } = require('../db');

// arbitrary key for the advisory lock that serializes the generation of ticket codes
const TICKET_CODE_LOCK = 8001;

// Mapping snake_case -> camelCase
function toTicket(row) {            
  return {
    id: row.id,
    code: row.code,
    serviceId: row.service_id,
    status: row.status,
    issuedAt: row.issued_at,
    servedAt: row.served_at,
    counterId: row.counter_id,
  };
}

// returns the ticket with the given id, or null if it does not exist.
async function getTicket(id) {
  const { rows } = await query(
    `SELECT id, code, service_id, status, issued_at, served_at, counter_id
     FROM "schema_OQM".tickets
     WHERE id = $1`,
    [id]
  );
  return rows.length ? toTicket(rows[0]) : null;
}

// issues a new ticket (status 'waiting') for the given service and returns it
// the code is unique for the whole office: 'A' + progressive number (A001, A002, ...)
async function createTicket(serviceId) {
  if (!Number.isInteger(serviceId)) throw new Error('serviceId must be an integer');

  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    // serializes concurrent requests, so two tickets can never get the same number
    await client.query('SELECT pg_advisory_xact_lock($1)', [TICKET_CODE_LOCK]);
    // codes look like 'A007': drop the first letter and take the highest number
    const { rows: [{ next }] } = await client.query(
      `SELECT COALESCE(MAX(SUBSTRING(code FROM 2)::int), 0) + 1 AS next
       FROM "schema_OQM".tickets`
    );
    const code = 'A' + String(next).padStart(3, '0');
    const { rows } = await client.query(
      `INSERT INTO "schema_OQM".tickets (code, service_id)
       VALUES ($1, $2)
       RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,
      [code, serviceId]
    );
    await client.query('COMMIT');
    return toTicket(rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    // 23503 = foreign_key_violation (the service does not exist)
    if (error.code === '23503') throw new Error(`Service ${serviceId} does not exist`);
    throw error;
  } finally {
    client.release();
  }
}

// import db by writing -> require('./dao/ticketDao')
module.exports = { getTicket, createTicket };
