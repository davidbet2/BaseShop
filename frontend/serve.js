const http = require('http');
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, 'build', 'web');
const port = 9090;

const mimes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2',
  '.woff': 'font/woff',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

http.createServer((req, res) => {
  let filePath = path.join(dir, req.url === '/' ? 'index.html' : req.url.split('?')[0]);
  if (!fs.existsSync(filePath)) {
    filePath = path.join(dir, 'index.html');
  }
  const ext = path.extname(filePath);
  res.writeHead(200, { 'Content-Type': mimes[ext] || 'application/octet-stream' });
  fs.createReadStream(filePath).pipe(res);
}).listen(port, () => {
  console.log('Serving Flutter web on http://localhost:' + port);
});
