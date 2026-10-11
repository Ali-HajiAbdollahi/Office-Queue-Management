const { tableNames } = require('./schema');

// All ticket writers, including future Next customer, must acquire this lock first.

async function withOfficeTransaction(pool, action, { schema, clock } = {}) {

  const t = tableNames(schema);

  const client = await pool.connect();

  try {

    await client.query('BEGIN');

    const { rows: [state] } = await client.query(

      `SELECT business_day::text, timezone, reset_hour FROM ${t.office_state}

       WHERE singleton = true FOR UPDATE`

    );

    if (!state) throw new Error('Missing office_state: run the migration');

    // Sample time AFTER locking, not before a request waits across 06:00.

    const now = clock ? clock() : (await client.query('SELECT clock_timestamp() AS now')).rows[0].now;

    const { rows: [{ day }] } = await client.query(

      `SELECT ((($1::timestamptz AT TIME ZONE $2) - make_interval(hours => $3))::date)::text AS day`,

      [now, state.timezone, state.reset_hour]

    );

    if (state.business_day && day < state.business_day) throw new Error('Office clock moved backwards');

    let archived = 0;

    const reset = state.business_day !== day;

    if (reset) {

      const result = await client.query(

        `WITH previous AS (

          DELETE FROM ${t.tickets} WHERE business_day < $1::date RETURNING *

        ) INSERT INTO ${t.ticket_history}

          (id, code, service_id, status, issued_at, served_at, counter_id,

           business_day, daily_number, archived_at)

        SELECT id, code, service_id, status::text, issued_at, served_at, counter_id,

               business_day, daily_number, $2 FROM previous`, [day, now]

      );

      archived = result.rowCount;

      // Preserve today's imported tickets if the migration is run mid-day.

      await client.query(

        `UPDATE ${t.office_state} SET business_day = $1::date,

         last_number = (SELECT COALESCE(max(daily_number), 0) FROM ${t.tickets}

                        WHERE business_day = $1::date) WHERE singleton = true`, [day]

      );

    }

    const value = await action(client, { day, now, reset, archived, tables: t });

    await client.query('COMMIT');

    return value;

  } catch (error) {

    await client.query('ROLLBACK').catch(() => {});

    throw error;

  } finally {

    client.release();

  }

}

module.exports = { withOfficeTransaction };