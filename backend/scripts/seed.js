const { createPool } = require('../src/db');

 

async function seed(pool) {

  // Demo data, not inferred from Figma. Existing service configuration is preserved.

  await pool.query(`INSERT INTO services(tag, service_time)

    VALUES ('Delivery', 5), ('Deposit', 8), ('Accounts', 10)

    ON CONFLICT (tag) DO NOTHING`);

}

if (require.main === module) {

  const pool = createPool();

  seed(pool).then(() => console.log('Demo services ready'))

    .catch((error) => { console.error(error.message); process.exitCode = 1; })

    .finally(() => pool.end());

}

module.exports = { seed };