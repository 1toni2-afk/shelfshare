const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'frontend', 'build', 'web');
const port = 5959;

const mime = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
};

http.createServer((req, res) => {
  let reqPath = decodeURIComponent(req.url.split('?')[0]);
  if (reqPath === '/') reqPath = '/index.html';
  let filePath = path.join(root, reqPath);

  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  // main.dart.js/flutter_service_worker.js/index.html etc. nu au niciun hash
  // în nume - Cloudflare și browserul le-ar cache-ui agresiv altfel (am tot
  // pățit asta la fiecare deploy: build nou pe server, dar userii tot pe
  // versiunea veche). Doar /assets/ (fonturi, imagini) au conținut stabil
  // per build și pot fi cache-uite normal.
  const isVersionedAsset = reqPath.startsWith('/assets/');
  const cacheControl = isVersionedAsset
    ? 'public, max-age=31536000, immutable'
    : 'no-cache, no-store, must-revalidate';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      fs.readFile(path.join(root, 'index.html'), (err2, indexData) => {
        if (err2) {
          res.writeHead(404);
          res.end('Not found');
          return;
        }
        res.writeHead(200, { 'Content-Type': 'text/html', 'Cache-Control': 'no-cache, no-store, must-revalidate' });
        res.end(indexData);
      });
      return;
    }
    const ext = path.extname(filePath);
    res.writeHead(200, {
      'Content-Type': mime[ext] || 'application/octet-stream',
      'Cache-Control': cacheControl,
    });
    res.end(data);
  });
}).listen(port, '127.0.0.1', () => {
  console.log(`Static server running at http://127.0.0.1:${port}`);
});
