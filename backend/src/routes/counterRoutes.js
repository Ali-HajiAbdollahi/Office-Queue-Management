const express = require("express");
const counterController = require("../controllers/counterController");

const router = express.Router();

router.post("/counters/:counter_id/call-next", counterController.callNext);
router.put("/tickets/:ticket_id/complete", counterController.completeTicket);

module.exports = router;
