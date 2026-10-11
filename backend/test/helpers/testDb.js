const { randomBytes } = require('node:crypto');

// Integration and e2e tests run against TEST_DATABASE_URL, inside a throwaway schema
// with a random name: the real schema (schema_OQM) is never read or written.
const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;
const skipReason = TEST_DATABASE_URL ? false : 'TEST_DATABASE_URL is not set (see backend/.env.example)';

if (TEST_DATABASE_URL) {
  process.env.DATABASE_URL = TEST_DATABASE_URL;
  process.env.DB_SCHEMA = `oqm_test_${randomBytes(4).toString('hex')}`;
}

const { query, closePool } = require('../../src/db');
const { quoteIdentifier, tableNames } = require('../../src/schema');

// mirrors the tables of schema_OQM on Neon (columns, types, lengths and constraints).
// Neon has no index from sql/001_customer_constraints.sql, so neither do the tests.
async function createSchema() {
  const schema = quoteIdentifier(process.env.DB_SCHEMA);
  const t = tableNames();
  await query(`
    CREATE SCHEMA ${schema};
    CREATE TYPE ${schema}.tkt_status AS ENUM ('waiting', 'called', 'completed');
    CREATE TABLE ${t.services} (
      id serial PRIMARY KEY,
      tag varchar(25) NOT NULL UNIQUE,
      service_time integer NOT NULL CHECK (service_time > 0)
    );
    CREATE TABLE ${t.counters} (
      id serial PRIMARY KEY,
      name varchar NOT NULL UNIQUE
    );
    CREATE TABLE ${t.counter_services} (
      counter_id integer NOT NULL REFERENCES ${t.counters} (id),
      service_id integer NOT NULL REFERENCES ${t.services} (id),
      PRIMARY KEY (counter_id, service_id)
    );
    CREATE TABLE ${t.tickets} (
      id serial PRIMARY KEY,
      code varchar(6) NOT NULL,
      service_id integer NOT NULL REFERENCES ${t.services} (id),
      status ${schema}.tkt_status NOT NULL DEFAULT 'waiting',
      issued_at timestamptz NOT NULL DEFAULT now(),
      served_at timestamptz,
      counter_id integer REFERENCES ${t.counters} (id)
    );
  `);
}

async function resetData() {
  const t = tableNames();
  await query(`TRUNCATE ${t.tickets}, ${t.counter_services}, ${t.counters}, ${t.services} RESTART IDENTITY CASCADE`);
}

async function dropSchema() {
  try {
    await query(`DROP SCHEMA IF EXISTS ${quoteIdentifier(process.env.DB_SCHEMA)} CASCADE`);
  } finally {
    await closePool();
  }
}

// returns the id of the new service
async function addService(tag, serviceTime) {
  const t = tableNames();
  const { rows: [row] } = await query(
    `INSERT INTO ${t.services} (tag, service_time) VALUES ($1, $2) RETURNING id`,
    [tag, serviceTime]
  );
  return row.id;
}

// returns the id of the new counter, linked to the given services
async function addCounter(name, serviceIds = []) {
  const t = tableNames();
  const { rows: [row] } = await query(`INSERT INTO ${t.counters} (name) VALUES ($1) RETURNING id`, [name]);
  for (const serviceId of serviceIds) {
    await query(`INSERT INTO ${t.counter_services} (counter_id, service_id) VALUES ($1, $2)`, [row.id, serviceId]);
  }
  return row.id;
}

// inserts a ticket directly, e.g. one issued on a previous day; returns its id
async function addTicket(serviceId, code, { status = 'waiting', daysAgo = 0, counterId = null } = {}) {
  const t = tableNames();
  const { rows: [row] } = await query(
    `INSERT INTO ${t.tickets} (code, service_id, status, issued_at, counter_id)
     VALUES ($1, $2, $3, now() - make_interval(days => $4), $5)
     RETURNING id`,
    [code, serviceId, status, daysAgo, counterId]
  );
  return row.id;
}

async function getTicketRow(id) {
  const t = tableNames();
  const { rows } = await query(`SELECT * FROM ${t.tickets} WHERE id = $1`, [id]);
  return rows[0];
}

module.exports = {
  skipReason, createSchema, resetData, dropSchema,
  addService, addCounter, addTicket, getTicketRow,
};
