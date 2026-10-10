const { query } = require('../db');

// Mapping snake_case -> camelCase
function toService(row) {
  return {
    id: row.id,
    tag: row.tag,
    serviceTime: row.service_time,
  };
}

// creates a service type and returns it
// tag: name that identifies the service type, serviceTime: average time (in minutes) to process it
async function createService(tag, serviceTime) {
  const cleanTag = typeof tag === 'string' ? tag.trim() : '';
  if (!cleanTag) throw new Error('tag is required');
  if (!Number.isInteger(serviceTime) || serviceTime <= 0) {
    throw new Error('serviceTime must be a positive integer');
  }

  try {
    const { rows } = await query(
      `INSERT INTO "schema_OQM".services (tag, service_time)
       VALUES ($1, $2)
       RETURNING id, tag, service_time`,
      [cleanTag, serviceTime]
    );
    return toService(rows[0]);
  } catch (error) {
    // 23505 = unique_violation (services.tag is unique)
    if (error.code === '23505') throw new Error(`Service "${cleanTag}" already exists`);
    throw error;
  }
}

// returns the service with the given id, or null if it does not exist.
async function getService(id) {
  const { rows } = await query(
    `SELECT id, tag, service_time
     FROM "schema_OQM".services
     WHERE id = $1`,
    [id]
  );
  return rows.length ? toService(rows[0]) : null;
}

// returns all the services, ordered by id
async function getServices() {
  const { rows } = await query(
    `SELECT id, tag, service_time
     FROM "schema_OQM".services
     ORDER BY id`
  );
  return rows.map(toService);
}

// import db by writing -> require('./dao/serviceDao')
module.exports = { createService, getService, getServices };
