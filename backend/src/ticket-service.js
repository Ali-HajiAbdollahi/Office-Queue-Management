const { withOfficeTransaction } = require('./office');

const { tableNames } = require('./schema');

const { validateServiceId, formatTicketCode, MAX_DAILY_TICKETS } = require('./validation');

const { HttpError } = require('./errors');

function createTicketService(pool, options = {}) {

  const t = tableNames(options.schema);

  const transaction = action => withOfficeTransaction(pool, action, options);

  async function issueTicket(serviceId) {

    validateServiceId(serviceId);

    return transaction(async (client, { day, now }) => {

      const { rows: [service] } = await client.query(

        `SELECT id, ticket_prefix FROM ${t.services} WHERE id = $1 FOR SHARE`, [serviceId]

      );

      if (!service) throw new HttpError(404, 'Service not found', 'SERVICE_NOT_FOUND');

      formatTicketCode(service.ticket_prefix, 1); // Check config before consuming a number.

      const sequence = await client.query(

        `UPDATE ${t.office_state} SET last_number = last_number + 1

         WHERE singleton = true AND last_number < $1 RETURNING last_number`, [MAX_DAILY_TICKETS]

      );

      if (!sequence.rowCount) {

        throw new HttpError(409, 'Daily ticket limit reached', 'DAILY_TICKET_LIMIT_REACHED');

      }

      const number = sequence.rows[0].last_number;

      const code = formatTicketCode(service.ticket_prefix, number);

      const inserted = await client.query(

        `INSERT INTO ${t.tickets}

         (code, service_id, status, issued_at, served_at, counter_id, business_day, daily_number)

         VALUES ($1, $2, 'waiting', $3, NULL, NULL, $4::date, $5)

         RETURNING id, code, service_id AS "serviceId", status, issued_at AS "issuedAt",

                   served_at AS "servedAt", counter_id AS "counterId",

                   business_day::text AS "businessDay", daily_number AS "dailyNumber"`,

        [code, serviceId, now, day, number]

      );

      return { ticket: inserted.rows[0] };

    });

  }

  async function resetIfNeeded() {

    return transaction(async (_client, { day, reset, archived }) => ({ businessDay: day, reset, archived }));

  }

  async function listServices() {

    return (await pool.query(

      `SELECT id, tag, service_time AS "serviceTime", ticket_prefix AS "ticketPrefix"

       FROM ${t.services} ORDER BY id`

    )).rows;

  }

  return { issueTicket, resetIfNeeded, listServices };

}

module.exports = { createTicketService };