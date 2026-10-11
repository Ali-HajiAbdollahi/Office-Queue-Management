function quoteIdentifier(value) {
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(value)) throw new Error('Invalid DB_SCHEMA');
  return `"${value}"`;
}

// fully qualified names of the tables, e.g. "schema_OQM"."tickets"
function tableNames(schema = process.env.DB_SCHEMA || 'schema_OQM') {
  const prefix = quoteIdentifier(schema);
  return Object.fromEntries(['services', 'tickets', 'counters', 'counter_services']
    .map(name => [name, `${prefix}."${name}"`]));
}

module.exports = { quoteIdentifier, tableNames };
