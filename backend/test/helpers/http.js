// starts an app on a random local port; returns its base url and a close function
async function listen(app) {
  const server = await new Promise((resolve, reject) => {
    const listener = app.listen(0, '127.0.0.1', () => resolve(listener));
    listener.once('error', reject);
  });
  return {
    url: `http://127.0.0.1:${server.address().port}`,
    close: () => new Promise(resolve => {
      server.closeAllConnections();
      server.close(resolve);
    }),
  };
}

// fetch wrapper: returns status, headers and the parsed JSON body (null when empty)
async function request(url, { method = 'GET', body, headers = {} } = {}) {
  const options = { method, headers: { ...headers } };
  if (body !== undefined) {
    options.body = typeof body === 'string' ? body : JSON.stringify(body);
    if (!options.headers['Content-Type']) options.headers['Content-Type'] = 'application/json';
  }
  const response = await fetch(url, options);
  const text = await response.text();
  return { status: response.status, headers: response.headers, body: text ? JSON.parse(text) : null };
}

module.exports = { listen, request };
