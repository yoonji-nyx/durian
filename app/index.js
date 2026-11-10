const http = require('node:http');

function handler(req, res) {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok' }));
  }
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('hello from sample-app 2v\n');
}

if (require.main === module) {
  const port = process.env.PORT || 3000;
  http.createServer(handler).listen(port, () => console.log(`listening on ${port}`));
}

module.exports = { handler };
