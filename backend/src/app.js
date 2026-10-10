const express = require("express");
const cors = require("cors");
const counterRoutes = require("./routes/counterRoutes");
const { errorMiddleware } = require("./middlewares/error.middleware");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/api/health", (req, res) => {
  res.json({ status: "ok" });
});

app.use("/api", counterRoutes);
app.use(errorMiddleware);

module.exports = app;
