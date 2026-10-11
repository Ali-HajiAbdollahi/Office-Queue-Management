const { getPool, query } = require('../db');
const { tableNames } = require('../schema');

const OFFICE_TIME_ZONE = 'Europe/Rome';
const OFFICE_RESET_HOUR = 6;

function businessDay(column) {
  return `((${column} AT TIME ZONE $1) - make_interval(hours => $2))::date`;
}

async function callNextTicket(counterId) {
  const { counters, services, counter_services: counterServices, tickets } = tableNames();
  const client = await getPool().connect();

  try {
    await client.query('BEGIN');

    const counterResult = await client.query(
      `SELECT id
       FROM ${counters}
       WHERE id = $1
       FOR UPDATE`,
      [counterId]
    );

    if (counterResult.rowCount === 0) {
      const error = new Error('Counter not found');
      error.code = 'COUNTER_NOT_FOUND';
      throw error;
    }

    const serviceResult = await client.query(
      `SELECT
         s.id,
         s.service_time,
         COUNT(t.id)::int AS waiting_count
       FROM ${counterServices} AS cs
       JOIN ${services} AS s
         ON s.id = cs.service_id
       LEFT JOIN ${tickets} AS t
         ON t.service_id = s.id
        AND t.status = 'waiting'
        AND ${businessDay('t.issued_at')} = ${businessDay('statement_timestamp()')}
       WHERE cs.counter_id = $3
       GROUP BY s.id, s.service_time
       HAVING COUNT(t.id) > 0
       ORDER BY waiting_count DESC, s.service_time ASC, s.id ASC
       LIMIT 1`,
      [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, counterId]
    );

    if (serviceResult.rowCount === 0) {
      await client.query('COMMIT');
      return null;
    }

    const serviceId = serviceResult.rows[0].id;
    const ticketResult = await client.query(
      `SELECT id
       FROM ${tickets}
       WHERE service_id = $3
         AND status = 'waiting'
         AND ${businessDay('issued_at')} = ${businessDay('statement_timestamp()')}
       ORDER BY issued_at ASC, id ASC
       LIMIT 1
       FOR UPDATE`,
      [OFFICE_TIME_ZONE, OFFICE_RESET_HOUR, serviceId]
    );

    if (ticketResult.rowCount === 0) {
      await client.query('COMMIT');
      return null;
    }

    const ticketId = ticketResult.rows[0].id;
    const updatedResult = await client.query(
      `UPDATE ${tickets}
       SET status = 'called',
           counter_id = $2,
           served_at = NOW()
       WHERE id = $1
       RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,
      [ticketId, counterId]
    );

    await client.query('COMMIT');
    return updatedResult.rows[0];
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {
      // Preserve the original error.
    }
    throw error;
  } finally {
    client.release();
  }
}

async function completeTicket(ticketId) {
  const { tickets } = tableNames();
  const updatedResult = await query(
    `UPDATE ${tickets}
     SET status = 'completed'
     WHERE id = $1
       AND status = 'called'
     RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,
    [ticketId]
  );

  if (updatedResult.rowCount > 0) {
    return updatedResult.rows[0];
  }

  const existingResult = await query(
    `SELECT id, status
     FROM ${tickets}
     WHERE id = $1`,
    [ticketId]
  );

  if (existingResult.rowCount === 0) {
    const error = new Error('Ticket not found');
    error.code = 'TICKET_NOT_FOUND';
    throw error;
  }

  const error = new Error('Ticket must be called before it can be completed');
  error.code = 'TICKET_NOT_CALLED';
  throw error;
}

async function listCounters() {
  const { counters } = tableNames();
  const result = await query(
    `SELECT id, name
     FROM ${counters}
     ORDER BY id ASC`
  );

  return result.rows;
}

module.exports = { callNextTicket, completeTicket, listCounters };