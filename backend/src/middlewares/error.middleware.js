function errorMiddleware(error, req, res, next) {
  const statusCode = error.statusCode || 500;

  res.status(statusCode).json({
    error: error.statusCode ? error.message : "Internal server error",
  });
}

module.exports = { errorMiddleware };
