const http = require('http');
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, 'build', 'web');
const port = 8080;

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

const securityHeaders = {
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'X-XSS-Protection': '1; mode=block',
};

http.createServer((req, res) => {
  // Path traversal protection: reject requests containing '..'
  const urlPath = req.url.split('?')[0];
  if (urlPath.includes('..')) {
    res.writeHead(400, { ...securityHeaders, 'Content-Type': 'text/plain' });
    res.end('Bad Request');
    return;
  }

  let filePath = path.join(dir, urlPath === '/' ? 'index.html' : urlPath);
  // Ensure resolved path is within the served directory
  const resolvedPath = path.resolve(filePath);
  if (!resolvedPath.startsWith(path.resolve(dir))) {
    res.writeHead(403, { ...securityHeaders, 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  if (!fs.existsSync(filePath)) {
    filePath = path.join(dir, 'index.html');
  }
  const ext = path.extname(filePath);
  res.writeHead(200, { ...securityHeaders, 'Content-Type': mimes[ext] || 'application/octet-stream' });
  fs.createReadStream(filePath).pipe(res);
}).listen(port, () => {
  console.log('Serving Flutter web on http://localhost:' + port);
});
