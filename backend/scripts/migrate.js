const { createPool } = require('../src/db');

const { tableNames, quoteIdentifier } = require('../src/schema');

async function migrate(pool, { schema = process.env.DB_SCHEMA || 'schema_OQM',

  legacyTimezone = process.env.LEGACY_TIMESTAMP_TIMEZONE } = {}) {

  const t = tableNames(schema);

  const c = await pool.connect();

  try {

    await c.query('BEGIN');

    await c.query('SELECT pg_advisory_xact_lock(6811, 2)');

    await c.query(`CREATE TABLE IF NOT EXISTS ${t.oqm_migrations}

      (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`);

    const done = await c.query(`SELECT 1 FROM ${t.oqm_migrations} WHERE version='002_neon_get_ticket'`);

    if (done.rowCount) { await c.query('COMMIT'); return; }

    await c.query(`LOCK TABLE ${t.services}, ${t.tickets} IN ACCESS EXCLUSIVE MODE`);

    const { rows: columns } = await c.query(

      `SELECT table_name,column_name,data_type,character_maximum_length,is_nullable

       FROM information_schema.columns WHERE table_schema=$1`, [schema]);

    const col = (table, name) => columns.find(x => x.table_name === table && x.column_name === name);

    for (const [table, names] of Object.entries({

      services: ['id','tag','service_time'],

      tickets: ['id','code','service_id','status','issued_at','served_at','counter_id']

    })) for (const name of names) if (!col(table,name)) throw Error(`Missing ${table}.${name}`);

    if (col('tickets','code').character_maximum_length !== 6)

      throw Error('Expected tickets.code varchar(6): review database contract');

    if (col('tickets','counter_id').is_nullable !== 'YES') throw Error('counter_id must allow NULL');

    const labels = await c.query(`SELECT e.enumlabel FROM pg_enum e

      JOIN pg_attribute a ON a.atttypid=e.enumtypid

      WHERE a.attrelid=$1::regclass AND a.attname='status'`, [t.tickets]);

    if (!['waiting','served'].every(x => labels.rows.some(r => r.enumlabel === x)))

      throw Error('Expected status enum with waiting and served');

    const count = Number((await c.query(`SELECT count(*) AS n FROM ${t.tickets}`)).rows[0].n);

    for (const name of ['issued_at','served_at']) {

      const type = col('tickets',name).data_type;

      if (type === 'timestamp with time zone') continue;

      if (type !== 'timestamp without time zone') throw Error(`Unexpected type: ${name}`);

      if (count && !legacyTimezone) throw Error('Set LEGACY_TIMESTAMP_TIMEZONE for existing timestamps');

      const zone = legacyTimezone || 'Europe/Rome';

      const valid = await c.query('SELECT 1 FROM pg_timezone_names WHERE name=$1',[zone]);

      if (!valid.rowCount) throw Error('Unknown legacy timezone');

      const literal = "'" + zone.replace(/'/g,"''") + "'";

      await c.query(`ALTER TABLE ${t.tickets} ALTER COLUMN ${quoteIdentifier(name)}

        TYPE timestamptz USING ${quoteIdentifier(name)} AT TIME ZONE ${literal}`);

    }

    // Existing rows retain their codes; ambiguous data causes a full rollback.

    const invalid = await c.query(`SELECT id FROM ${t.tickets}

      WHERE code !~ '^[A-Z]-[0-9]{1,4}$' LIMIT 1`);

    if (invalid.rowCount) throw Error('Existing ticket code cannot be migrated automatically');

    await c.query(`ALTER TABLE ${t.services}

      ADD COLUMN ticket_prefix varchar(1) UNIQUE,

      ADD CONSTRAINT oqm_prefix_check CHECK (ticket_prefix ~ '^[A-Z]$')`);

    await c.query(`ALTER TABLE ${t.tickets}

      ADD COLUMN business_day date, ADD COLUMN daily_number integer`);

    await c.query(`UPDATE ${t.tickets} SET

      business_day=((issued_at AT TIME ZONE 'Europe/Rome')-interval '6 hours')::date,

      daily_number=split_part(code,'-',2)::integer`);

    await c.query(`ALTER TABLE ${t.tickets}

      ALTER COLUMN business_day SET NOT NULL,

      ALTER COLUMN daily_number SET NOT NULL,

      ADD CONSTRAINT oqm_number_check CHECK (daily_number BETWEEN 1 AND 9999),

      ADD CONSTRAINT oqm_day_number_unique UNIQUE(business_day,daily_number),

      ADD CONSTRAINT oqm_day_code_unique UNIQUE(business_day,code)`);

    await c.query(`CREATE TABLE ${t.office_state} (

      singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),

      business_day date, last_number integer NOT NULL DEFAULT 0

        CHECK(last_number BETWEEN 0 AND 9999),

      timezone text NOT NULL DEFAULT 'Europe/Rome',

      reset_hour integer NOT NULL DEFAULT 6 CHECK(reset_hour BETWEEN 0 AND 23))`);

    await c.query(`INSERT INTO ${t.office_state}(singleton) VALUES(true)`);

    await c.query(`CREATE TABLE ${t.ticket_history} (

      id integer PRIMARY KEY, code varchar(6) NOT NULL, service_id integer NOT NULL,

      status text NOT NULL CHECK(status IN ('waiting','served')),

      issued_at timestamptz NOT NULL, served_at timestamptz, counter_id integer,

      business_day date NOT NULL, daily_number integer NOT NULL,

      archived_at timestamptz NOT NULL,

      UNIQUE(business_day,daily_number), UNIQUE(business_day,code))`);

    await c.query(`CREATE INDEX oqm_get_ticket_queue_idx

      ON ${t.tickets}(business_day,service_id,status)`);

    await c.query(`INSERT INTO ${t.oqm_migrations}(version) VALUES('002_neon_get_ticket')`);

    await c.query('COMMIT');

  } catch (error) {

    await c.query('ROLLBACK').catch(() => {});

    throw error;

  } finally { c.release(); }

}

if (require.main === module) {

  const pool = createPool(process.env.DIRECT_DATABASE_URL || process.env.DATABASE_URL);

  migrate(pool).then(() => console.log('Migration complete'))

    .catch(error => { console.error(error.message); process.exitCode=1; })

    .finally(() => pool.end());

}

module.exports = { migrate };