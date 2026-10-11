# Customer API contract

 

Applies to the customer fixes based on `fix/db_conflicts` commit

`8e14f223c4a1799382063ab4524ba6ac6f3c0afa`.

Append/link this section from the team's `API_ENDPOINTS.md`; preserve the Officer section.

 

## Rules

 

- Base URL in local development: `http://localhost:3000`.

- JSON fields use snake_case. POST requires `Content-Type: application/json`.

- Daily sequence is per service, from 0001 through 9999, with a unique service initial.

- A working day starts at 06:00 Europe/Rome. Older tickets remain in `tickets`.

- Database status remains `waiting` or `served`. This change does not implement Officer transitions.

- `is_active` means status `waiting` AND issued in the current working day. It is computed, not stored.

- `queue_length` is the service's total current waiting count, including the new ticket for POST.

  It is not the customer's queue position or an estimated waiting time.

- Ticket `id` is permanent and used in URLs; displayed `code` may repeat on another day.

- GET responses and POST responses set `Cache-Control: no-store`.

- No automatic retry of POST on network timeout: a lost response can follow a successful commit.

 

## GET /api/services

 

200, array (including an empty array when no services exist):

 

```json

[{"id":1,"tag":"Assurance","service_time":10}]

```

 

`service_time` is average service duration in minutes, not estimated queue wait.

 

## POST /api/tickets

 

Request:

 

```json

{"service_id":1}

```

 

201, flat object:

 

```json

{

  "id":42,

  "code":"A-0001",

  "service_id":1,

  "status":"waiting",

  "issued_at":"2026-10-11T08:00:00.000Z",

  "served_at":null,

  "counter_id":null,

  "is_active":true,

  "queue_length":1

}

```

 

The examples are illustrative. Save the returned id for later GET requests.

 

## GET /api/tickets/{ticket_id}

 

Example: `GET /api/tickets/42`. The URL uses a positive integer id, not `A-0001`.

 

200, same ticket fields as POST except `queue_length` is absent:

 

```json

{

  "id":42,

  "code":"A-0001",

  "service_id":1,

  "status":"waiting",

  "issued_at":"2026-10-11T08:00:00.000Z",

  "served_at":null,

  "counter_id":null,

  "is_active":true

}

```

 

An older waiting ticket still returns 200 with `status: "waiting"` and `is_active: false`.

A served ticket returns 200 with `status: "served"` and `is_active: false`.

Neither case deletes or changes the ticket. Unknown ids return 404; malformed ids return 400.

 

## GET /api/queues

 

200:

 

```json

{

  "queues":[

    {"service_id":1,"tag":"Assurance","service_time":10,"queue_length":3},

    {"service_id":2,"tag":"Delivery","service_time":5,"queue_length":0}

  ]

}

```

 

All services are included, including zero-length queues. Only current working-day waiting tickets count.

 

## Errors

 

Domain/validation errors have this format:

 

```json

{"error":{"code":"DAILY_LIMIT_REACHED","message":"Daily ticket limit reached"}}

```

 

| Status | Code or condition |

| --- | --- |

| 400 | INVALID_SERVICE_ID, INVALID_TICKET_ID or invalid JSON |

| 404 | SERVICE_NOT_FOUND, TICKET_NOT_FOUND or unknown route |

| 409 | SERVICE_TAG_INVALID or DAILY_LIMIT_REACHED |

| 413 | JSON body exceeds 16 KB |

| 415 | POST Content-Type is not application/json |

| 500 | Unexpected server/database error |

 

Invalid JSON, body size, unknown routes and generic server errors retain the branch's

string form, e.g. `{"error":"Internal server error"}`. The frontend must accept either

a string or an object inside `error`.

 

## Ownership and boundaries

 

The customer package implements the four routes above. `/api/services` and POST

`/api/tickets` already existed in the base branch; GET ticket by id is newly added.

 

`GET /api/counters`, `GET /api/counters/{counter_id}/queue-stats`, call-next and

complete belong to the Officer task owners and must be documented with their real implementations.

This package does not add those routes.

 

There is no `GET /api/tickets/active` or `DELETE /api/tickets/{id}` here.

The device stores its active id locally; cancellation must remain disabled until its own API is agreed.

There is no user authentication or ticket ownership check in this prototype.