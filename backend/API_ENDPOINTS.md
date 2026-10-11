# API Endpoints

Base URL: `http://localhost:3000/api`

This document describes the REST endpoints requested in `api.txt`. It is an API specification; documenting an endpoint does not mean the backend route is already implemented.

## Customer App

### 1. List available services

```http
GET /services
```

Returns the available services.

**Success — 200 OK**

```json
[
  { "id": 1, "tag": "General Inquiries", "service_time": 5 }
]
```

### 2. Create a ticket

```http
POST /tickets
Content-Type: application/json
```

**Request body**

```json
{ "service_id": 1 }
```

**Success — 201 Created**

Returns the newly created ticket. Example:

```json
{
  "id": 101,
  "code": "A-142",
  "service_id": 1,
  "status": "waiting",
  "issued_at": "2026-10-10T12:00:00.000Z"
}
```

### 3. Get ticket status

```http
GET /tickets/{ticket_id}
```

Returns the current ticket, including its status (for example, `waiting`, `called`, or `completed`).

**Success — 200 OK**

The response is the ticket object, using the same fields as the create-ticket response. Fields such as `served_at` and `counter_id` can be present after a ticket is called.

### 4. Cancel a waiting ticket

The source API file allows either `DELETE /tickets/{ticket_id}` or `POST /tickets/{ticket_id}/cancel`. The exact route should be agreed on by the team before implementation. The examples below document the DELETE option.

```http
DELETE /tickets/{ticket_id}
```

Cancels a ticket that is still waiting.

**Success — 200 OK**

A successful response confirms the ticket was cancelled. The source API file does not specify the response body.

## Counter Officer Dashboard

### 5. List counters

```http
GET /counters
```

Returns the counters available for selection.

**Success — 200 OK**

```json
[
  { "id": 2, "name": "Counter 2" }
]
```

### 6. Call the next ticket

```http
POST /counters/{counter_id}/call-next
```

Calls the oldest waiting ticket for a service that the selected counter can serve. The source API file does not define how to choose between multiple eligible service queues; the existing implementation in this branch selects the queue with the most waiting tickets, breaking ties by shorter `service_time`, then selects the oldest waiting ticket in that queue.

**Success — 200 OK**

Returns the called ticket:

```json
{
  "id": 3,
  "code": "A002",
  "service_id": 1,
  "status": "called",
  "issued_at": "2026-10-10T12:00:00.000Z",
  "served_at": "2026-10-10T12:05:00.000Z",
  "counter_id": 2
}
```

**Errors**

- `400 Bad Request` — `counter_id` is not a positive integer.
- `404 Not Found` — The counter does not exist, or no waiting ticket is available for its services.
- `500 Internal Server Error` — An unexpected server error occurred.

### 7. Complete a ticket

```http
PUT /tickets/{ticket_id}/complete
```

Marks a called ticket as completed after service is finished.

**Success — 200 OK**

Returns the updated ticket, with `status: "completed"`.

**Errors**

- `400 Bad Request` — `ticket_id` is not a positive integer.
- `404 Not Found` — The ticket does not exist.
- `409 Conflict` — The ticket has not been called and cannot be completed.
- `500 Internal Server Error` — An unexpected server error occurred.

### 8. Recall a ticket

```http
POST /tickets/{ticket_id}/recall
```

Triggers the ticket announcement again. The source API file says this does not change the database state and should trigger a real-time event.

**Success — 200 OK**

The source API file does not specify a response body.

### 9. Get counter history

```http
GET /counters/{counter_id}/history
```

Returns the tickets completed by this counter today.

**Success — 200 OK**

Returns an array of completed ticket objects. The source API file does not specify the exact fields.

### 10. Get queue statistics

```http
GET /counters/{counter_id}/queue-stats
```

Returns queue data for the counter dashboard.

**Success — 200 OK**

```json
{
  "waiting_count": 4,
  "avg_wait_time": 6,
  "next_ticket_code": "A-142"
}
```

## Real-time notifications

The source API file also requires WebSocket or Server-Sent Events (SSE) notifications. It does not specify the connection URL or event payload format; those need to be agreed on separately.

- When a ticket is called, notify the customer app, public display, and other officers.
- When a ticket is created, notify counter officers so their queue counts update.
- When a ticket is recalled, notify the public display to show and announce it again.

