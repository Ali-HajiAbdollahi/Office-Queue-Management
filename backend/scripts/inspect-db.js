const { createPool } = require('../src/db');

async function inspect(pool, schema) {

  const tables = await pool.query(

    `SELECT table_name, column_name, data_type, udt_schema, udt_name,

            character_maximum_length, is_nullable, column_default

     FROM information_schema.columns WHERE table_schema = $1

     ORDER BY table_name, ordinal_position`, [schema]

  );

  if (!tables.rowCount) throw new Error('Schema not found or role cannot access it: check DB_SCHEMA case');

  console.table(tables.rows);

  console.table((await pool.query(

    `SELECT t.typname, e.enumlabel FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace

     JOIN pg_enum e ON e.enumtypid = t.oid WHERE n.nspname = $1 ORDER BY t.typname, e.enumsortorder`, [schema]

  )).rows);

}

if (require.main === module) {

  const pool = createPool(process.env.DIRECT_DATABASE_URL || process.env.DATABASE_URL);

  inspect(pool, process.env.DB_SCHEMA || 'schema_OQM')

    .catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => pool.end());

}

module.exports = { inspect };