const { query, getPool } = require('../db');
const { tableNames } = require('../schema');
const TICKET_CODE_LOCK = 8001;
const OFFICE_TIME_ZONE = 'Europe/Rome';
const OFFICE_RESET_HOUR = 6;
const MAX_DAILY_TICKETS = 9999;


function daoError(message, code) {
  const error = new Error(message);
  error.code = code;
  return error;
}


function businessDay(column) {
  return `((${column} AT TIME ZONE $1) - make_interval(hours => $2))::date`;
}

function toTicket(row) {
  return {
    id: row.id,
    code: row.code,
    serviceId: row.service_id,
    status: row.status,
    issuedAt: row.issued_at,
    servedAt: row.served_at,
    counterId: row.counter_id,
    isActive: row.is_active,
  };

}

// Historical tickets remain readable; isActive distinguishes today's queue.
async function getTicket(id) {
  const t = tableNames();
  const { rows } = await query(
    `SELECT id, code, service_id, status, issued_at, served_at, counter_id,
       (status = 'waiting' AND
        ${businessDay('issued_at')} = ${businessDay('statement_timestamp()')}) AS is_active
     FROM ${t.tickets} WHERE id = $3`,
    [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, id]
  );

  return rows.length ? toTicket(rows[0]) : null;
}

// Number allocation, insertion and queue count commit together.
async function createTicketWithQueue(serviceId) {
  if (!Number.isSafeInteger(serviceId) || serviceId < 1 || serviceId > 2147483647) {
    throw daoError('service_id must be a positive integer', 'INVALID_SERVICE_ID');
  }

  const t = tableNames();
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock($1)', [TICKET_CODE_LOCK]); 

    // Read the clock AFTER waiting for the lock. Reuse this exact instant.
    const { rows: [{ issued_at: issuedAt }] } = await client.query(
      'SELECT clock_timestamp() AS issued_at'
    );

    const { rows: services } = await client.query(
      `SELECT tag FROM ${t.services} WHERE id = $1 FOR SHARE`, [serviceId]
    );

    if (!services.length) throw daoError('Service not found', 'SERVICE_NOT_FOUND');
    const initial = services[0].tag.trim().charAt(0).toUpperCase();
    if (!/^[A-Z]$/.test(initial)) {
      throw daoError('Service tag must start with a letter', 'SERVICE_TAG_INVALID');
    }

    const values = [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, serviceId, issuedAt];
    const { rows: [{ next }] } = await client.query(
      `SELECT COALESCE(MAX(SUBSTRING(code FROM 3)::int), 0) + 1 AS next
       FROM ${t.tickets}
       WHERE service_id = $3
         AND ${businessDay('issued_at')} = ${businessDay('$4::timestamptz')}`,
      values
    );

    if (next > MAX_DAILY_TICKETS) {
      throw daoError('Daily ticket limit reached', 'DAILY_LIMIT_REACHED');
    }

    const code = `${initial}-${String(next).padStart(4, '0')}`;
    const { rows: [row] } = await client.query(
      `INSERT INTO ${t.tickets}
         (code, service_id, status, issued_at, served_at, counter_id)
       VALUES ($1, $2, 'waiting', $3, NULL, NULL)
       RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,

      [code, serviceId, issuedAt]

    );

    const { rows: [{ length }] } = await client.query(

      `SELECT count(*)::int AS length FROM ${t.tickets}

       WHERE service_id = $3 AND status = 'waiting'

         AND ${businessDay('issued_at')} = ${businessDay('$4::timestamptz')}`,

      values

    );

    await client.query('COMMIT');

    return { ticket: toTicket({ ...row, is_active: true }), queueLength: length };

  } catch (error) {

    try { await client.query('ROLLBACK'); } catch (_) { /* Preserve original error. */ }

    if (error.code === '23503') {

      throw daoError('Service not found', 'SERVICE_NOT_FOUND');

    }

    throw error;

  } finally {

    client.release();

  }

}

 

// Retain the old DAO interface for other callers.

async function createTicket(serviceId) {

  return (await createTicketWithQueue(serviceId)).ticket;

}

 

async function getQueueLength(serviceId) {

  const t = tableNames();

  const { rows: [{ length }] } = await query(

    `SELECT count(*)::int AS length FROM ${t.tickets}

     WHERE service_id = $3 AND status = 'waiting'

       AND ${businessDay('issued_at')} = ${businessDay('statement_timestamp()')}`,

    [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, serviceId]

  );

  return length;

}

 

async function getQueues() {

  const t = tableNames();

  const { rows } = await query(

    `SELECT s.id, s.tag, s.service_time, count(tk.id)::int AS queue_length

     FROM ${t.services} s

     LEFT JOIN ${t.tickets} tk ON tk.service_id = s.id

       AND tk.status = 'waiting'

       AND ${businessDay('tk.issued_at')} = ${businessDay('statement_timestamp()')}

     GROUP BY s.id ORDER BY s.id`,

    [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR]

  );

  return rows.map(row => ({

    serviceId: row.id, tag: row.tag,

    serviceTime: row.service_time, queueLength: row.queue_length,

  }));

}

 

module.exports = {

  getTicket, createTicket, createTicketWithQueue,

  getQueueLength, getQueues, MAX_DAILY_TICKETS,

};

