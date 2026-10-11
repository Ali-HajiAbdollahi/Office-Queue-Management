const { query, getPool } = require('../db');

// arbitrary key for the advisory lock that serializes the generation of ticket codes
const TICKET_CODE_LOCK = 8001;
// the ticket numbers restart from 1 every day (in the office's time zone) and go up to 9999
const OFFICE_TIME_ZONE = 'Europe/Rome';
const MAX_DAILY_TICKETS = 9999;

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
// the code is 'X-NNNN': X = initial of the service tag, NNNN = progressive number (0001..9999)
// the number is progressive per service and restarts from 0001 every day (the queues are reset),
// so a code is unique only together with its issued_at day
async function createTicket(serviceId) {
  if (!Number.isInteger(serviceId)) throw new Error('serviceId must be an integer');

  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    // serializes concurrent requests, so two tickets can never get the same number
    await client.query('SELECT pg_advisory_xact_lock($1)', [TICKET_CODE_LOCK]);

    const { rows: serviceRows } = await client.query(
      `SELECT tag FROM "schema_OQM".services WHERE id = $1`,
      [serviceId]
    );
    if (!serviceRows.length) throw new Error(`Service ${serviceId} does not exist`);
    const initial = serviceRows[0].tag.trim().charAt(0).toUpperCase();
    if (!/^[A-Z]$/.test(initial)) throw new Error(`Service ${serviceId} has a tag that does not start with a letter`);

    // codes look like 'A-0007': skip the 'X-' and take the highest number issued today for this service
    const { rows: [{ next }] } = await client.query(
      `SELECT COALESCE(MAX(SUBSTRING(code FROM 3)::int), 0) + 1 AS next
       FROM "schema_OQM".tickets
       WHERE service_id = $2
         AND (issued_at AT TIME ZONE $1)::date = (now() AT TIME ZONE $1)::date`,
      [OFFICE_TIME_ZONE, serviceId]
    );
    if (next > MAX_DAILY_TICKETS) throw new Error('Daily ticket limit reached');
    const code = `${initial}-${String(next).padStart(4, '0')}`;
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
