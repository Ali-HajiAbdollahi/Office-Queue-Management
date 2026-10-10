API Endpoints
Base URL: http://localhost:3000/api
1. Call the Next Customer
Calls the next waiting ticket that the selected counter can serve.
Endpoint
POST /counters/{counter_id}/call-next
Path parameter
Parameter	Type	Description
counter_id	Integer	ID of the counter calling the next customer


Request body: None
Selection rules: The system selects the service queue with the most waiting tickets. If queues are tied, it selects the service with the shorter service_time. It then calls the oldest waiting ticket in that service queue.
Success response — 200 OK


{
  "id": 3,
  "code": "A002",
  "service_id": 1,
  "status": "called",
  "issued_at": "2026-10-10T12:00:00.000Z",
  "served_at": "2026-10-10T12:05:00.000Z",
  "counter_id": 2
}


Error responses
- 400 Bad Request — counter_id is not a positive integer.
- 404 Not Found — The counter does not exist, or there are no waiting tickets it can serve.
- 500 Internal Server Error — An unexpected server error occurred.
2. Complete a Ticket
Marks a called ticket as completed after the officer finishes serving the customer.
Endpoint
PUT /tickets/{ticket_id}/complete
Path parameter
Parameter	Type	Description
ticket_id	Integer	ID of the ticket to complete


Request body: None
Success response — 200 OK
Returns the updated ticket. Its status is completed.


{
  "id": 3,
  "code": "A002",
  "service_id": 1,
  "status": "completed",
  "issued_at": "2026-10-10T12:00:00.000Z",
  "served_at": "2026-10-10T12:05:00.000Z",
  "counter_id": 2
}


Error responses
- 400 Bad Request — ticket_id is not a positive integer.
- 404 Not Found — The ticket does not exist.
- 409 Conflict — The ticket has not been called and cannot be completed.
- 500 Internal Server Error — An unexpected server error occurred.