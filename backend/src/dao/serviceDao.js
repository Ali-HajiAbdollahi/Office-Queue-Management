const { query } = require('../db');
const { tableNames } = require('../schema');

 

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
// the ticket code starts with the initial of the tag, so two services cannot share the same initial
async function createService(tag, serviceTime) {
  const t = tableNames();
  const cleanTag = typeof tag === 'string' ? tag.trim() : '';
  if (!cleanTag) throw new Error('tag is required');
  if (!Number.isInteger(serviceTime) || serviceTime <= 0) {
    throw new Error('serviceTime must be a positive integer');
  }

  // throw error if the first char isn't a letter
  const initial = cleanTag.charAt(0).toUpperCase();
  if (!/^[A-Z]$/.test(initial)) throw new Error('tag must start with a letter');

  // verify if exists a service with the same letter
  const { rows: sameInitial } = await query(
    `SELECT tag FROM ${t.services} WHERE upper(left(btrim(tag), 1)) = $1 LIMIT 1`,
    [initial]
  );

  if (sameInitial.length) {
    const used = sameInitial[0].tag.trim();
    if (used === cleanTag) throw new Error(`Service "${cleanTag}" already exists`);
    throw new Error(`Initial "${initial}" is already used by service "${used}"`);
  }

  try {
    const { rows } = await query(
      `INSERT INTO ${t.services} (tag, service_time)
       VALUES ($1, $2)
       RETURNING id, tag, service_time`,
      [cleanTag, serviceTime]
    );
    return toService(rows[0]);
  } catch (error) {
    if (error.code === '23505' && error.constraint === 'uq_services_ticket_initial') {
      const conflict = new Error(`Initial "${initial}" is already used by another service`);
      conflict.code = 'SERVICE_INITIAL_CONFLICT';
      throw conflict;
    }

    // 23505 = unique_violation (services.tag is unique)
    if (error.code === '23505') throw new Error(`Service "${cleanTag}" already exists`);
    throw error;
  }
} 

// returns the service with the given id, or null if it does not exist.
async function getService(id) {
  const t = tableNames();
  const { rows } = await query(
    `SELECT id, tag, service_time
     FROM ${t.services}
     WHERE id = $1`,
    [id]
  );

  return rows.length ? toService(rows[0]) : null;

} 

// returns all the services, ordered by id
async function getServices() {
  const t = tableNames();
  const { rows } = await query(
    `SELECT id, tag, service_time
     FROM ${t.services}
     ORDER BY id`

  );
  return rows.map(toService);

}

// import db by writing -> require('./dao/serviceDao')
module.exports = { createService, getService, getServices };