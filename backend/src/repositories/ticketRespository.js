const { Pool } = require("pg");

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});


async function callNextTicket(counterId) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // Confirm that the counter exists and lock it to serialize calls from this counter.
    const counterResult = await client.query(
      `SELECT id
       FROM "schema_OQM".counters
       WHERE id = $1
       FOR UPDATE`,
      [counterId]
    );

    if (counterResult.rowCount === 0) {
      const error = new Error("Counter not found");
      error.code = "COUNTER_NOT_FOUND";
      throw error;
    }

    
    const serviceResult = await client.query(
      `SELECT
         s.id,
         s.service_time,
         COUNT(t.id)::int AS waiting_count
       FROM "schema_OQM".counter_services AS cs
       JOIN "schema_OQM".services AS s
         ON s.id = cs.service_id
       LEFT JOIN "schema_OQM".tickets AS t
         ON t.service_id = s.id
        AND t.status = 'waiting'
       WHERE cs.counter_id = $1
       GROUP BY s.id, s.service_time
       HAVING COUNT(t.id) > 0
       ORDER BY waiting_count DESC, s.service_time ASC, s.id ASC
       LIMIT 1`,
      [counterId]
    );

    
    if (serviceResult.rowCount === 0) {
      await client.query("COMMIT");
      return null;
    }

    const serviceId = serviceResult.rows[0].id;

    
    const ticketResult = await client.query(
      `SELECT id
       FROM "schema_OQM".tickets
       WHERE service_id = $1
         AND status = 'waiting'
       ORDER BY issued_at ASC, id ASC
       LIMIT 1
       FOR UPDATE`,
      [serviceId]
    );

    if (ticketResult.rowCount === 0) {
      await client.query("COMMIT");
      return null;
    }

    const ticketId = ticketResult.rows[0].id;

   
    const updatedResult = await client.query(
      `UPDATE "schema_OQM".tickets
       SET status = 'called',
           counter_id = $2,
           served_at = NOW()
       WHERE id = $1
       RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,
      [ticketId, counterId]
    );

    await client.query("COMMIT");
    return updatedResult.rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

async function completeTicket(ticketId) {
  const updatedResult = await pool.query(
    `UPDATE "schema_OQM".tickets
     SET status = 'completed'
     WHERE id = $1
       AND status = 'called'
     RETURNING id, code, service_id, status, issued_at, served_at, counter_id`,
    [ticketId]
  );

  if (updatedResult.rowCount > 0) {
    return updatedResult.rows[0];
  }

  const existingResult = await pool.query(
    `SELECT id, status
     FROM "schema_OQM".tickets
     WHERE id = $1`,
    [ticketId]
  );

  if (existingResult.rowCount === 0) {
    const error = new Error("Ticket not found");
    error.code = "TICKET_NOT_FOUND";
    throw error;
  }

  const error = new Error("Ticket must be called before it can be completed");
  error.code = "TICKET_NOT_CALLED";
  throw error;
}

async function listCounters() {
  const result = await pool.query(
    `SELECT id, name
     FROM "schema_OQM".counters
     ORDER BY id ASC`
  );

  return result.rows;
}

module.exports = { callNextTicket, completeTicket, listCounters };

