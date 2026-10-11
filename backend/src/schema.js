function quoteIdentifier(value) {

  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(value)) throw new Error('Invalid DB_SCHEMA');

  return `"${value}"`;

}

function tableNames(schema = process.env.DB_SCHEMA || 'schema_OQM') {

  const prefix = quoteIdentifier(schema);

  return Object.fromEntries(['services', 'tickets', 'office_state', 'ticket_history',

    'oqm_migrations', 'counters', 'counter_services'].map(name => [name, `${prefix}."${name}"`]));

}

module.exports = { quoteIdentifier, tableNames };