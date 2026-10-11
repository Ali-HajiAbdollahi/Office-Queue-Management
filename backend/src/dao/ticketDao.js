const { query, getPool } = require('../db');
const { tableNames } = require('../schema');

// arbitrary key for the advisory lock that serializes the generation of ticket codes
const TICKET_CODE_LOCK = 8001;
const OFFICE_TIME_ZONE = 'Europe/Rome';
// a working day starts at 06:00: a ticket issued at 02:00 still belongs to the previous day
const OFFICE_RESET_HOUR = 6;
const MAX_DAILY_TICKETS = 9999;

// error with a machine-readable code, so the callers can translate it (e.g. to an HTTP status)
function daoError(message, code) {
  const error = new Error(message);
  error.code = code;
  return error;
}

// SQL for the working day of a timestamp column, with $1 = time zone and $2 = reset hour
function businessDay(column) {
  return `((${column} AT TIME ZONE $1) - make_interval(hours => $2))::date`;
}

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
  const t = tableNames();
  const { rows } = await query(
    `SELECT id, code, service_id, status, issued_at, served_at, counter_id
     FROM ${t.tickets}
     WHERE id = $1`,
    [id]
  );
  return rows.length ? toTicket(rows[0]) : null;
}

// issues a new ticket (status 'waiting') for the given service and returns it
// the code is 'X-NNNN': X = initial of the service tag, NNNN = progressive number (0001..9999)
// the number is progressive per service and restarts from 0001 every working day (the queues are reset),
// so a code is unique only together with its issued_at day
// errors have a code: INVALID_SERVICE_ID, SERVICE_NOT_FOUND, SERVICE_TAG_INVALID, DAILY_LIMIT_REACHED
async function createTicket(serviceId) {
  if (!Number.isInteger(serviceId)) throw daoError('serviceId must be an integer', 'INVALID_SERVICE_ID');
  const t = tableNames();

  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    // serializes concurrent requests, so two tickets can never get the same number
    await client.query('SELECT pg_advisory_xact_lock($1)', [TICKET_CODE_LOCK]);

    const { rows: serviceRows } = await client.query(
      `SELECT tag FROM ${t.services} WHERE id = $1`,
      [serviceId]
    );
    if (!serviceRows.length) throw daoError(`Service ${serviceId} does not exist`, 'SERVICE_NOT_FOUND');
    
    // first service's letter
    const initial = serviceRows[0].tag.trim().charAt(0).toUpperCase();
    if (!/^[A-Z]$/.test(initial)) {
      throw daoError(`Service ${serviceId} has a tag that does not start with a letter`, 'SERVICE_TAG_INVALID');
    }

    // codes look like 'A-0007': skip the 'X-' and take the highest number issued today for this service
    const { rows: [{ next }] } = await client.query(
      `SELECT COALESCE(MAX(SUBSTRING(code FROM 3)::int), 0) + 1 AS next
       FROM ${t.tickets}
       WHERE service_id = $3
         AND ${businessDay('issued_at')} = ${businessDay('now()')}`,
      [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, serviceId]
    );

    // next > 9999
    if (next > MAX_DAILY_TICKETS) throw daoError('Daily ticket limit reached', 'DAILY_LIMIT_REACHED');
    
    // code = "X-NNNN"
    const code = `${initial}-${String(next).padStart(4, '0')}`;
    
    // insert into tickets table the new ticket informations
    // returns a json object of the ticket informations
    const { rows } = await client.query(
      `INSERT INTO ${t.tickets} (code, service_id)
       VALUES ($1, $2)
       RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,
      [code, serviceId]
    );
    await client.query('COMMIT');
    return toTicket(rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    // 23503 = foreign_key_violation (the service does not exist)
    if (error.code === '23503') throw daoError(`Service ${serviceId} does not exist`, 'SERVICE_NOT_FOUND');
    throw error;
  } finally {
    client.release();
  }
}

// returns how many tickets of the given service are waiting today
async function getQueueLength(serviceId) {
  const t = tableNames();
  const { rows: [{ length }] } = await query(
    `SELECT count(*)::int AS length
     FROM ${t.tickets}
     WHERE service_id = $3
       AND status = 'waiting'
       AND ${businessDay('issued_at')} = ${businessDay('now()')}`,
    [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, serviceId]
  );
  return length;
}

// returns every service with the number of tickets waiting today, ordered by service id
async function getQueues() {
  const t = tableNames();
  const { rows } = await query(
    `SELECT s.id, s.tag, s.service_time, count(tk.id)::int AS queue_length
     FROM ${t.services} s
     LEFT JOIN ${t.tickets} tk
       ON tk.service_id = s.id
      AND tk.status = 'waiting'
      AND ${businessDay('tk.issued_at')} = ${businessDay('now()')}
     GROUP BY s.id
     ORDER BY s.id`,
    [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR]
  );
  return rows.map(row => ({
    serviceId: row.id,
    tag: row.tag,
    serviceTime: row.service_time,
    queueLength: row.queue_length,
  }));
}

// import db by writing -> require('./dao/ticketDao')
module.exports = { getTicket, createTicket, getQueueLength, getQueues, MAX_DAILY_TICKETS };
