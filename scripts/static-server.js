const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

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

  // NICIUN fișier din build-ul Flutter web (main.dart.js, index.html, DAR și
  // tot ce e sub /assets/ - fonturi, imagini, AssetManifest.json) nu are hash
  // în nume: numele rămâne identic de la un build la altul, doar conținutul
  // se schimbă. Am tratat /assets/ ca "imuabil, cache 1 an" inițial, dar
  // asta a fost o presupunere greșită - ex. MaterialIcons-Regular.otf e
  // tree-shaken în funcție de iconițele folosite în cod, deci conținutul lui
  // SE schimbă de la un deploy la altul (o iconiță nouă adăugată la o feature
  // înseamnă un font nou, la același URL) - un vizitator care a cache-uit
  // fontul vechi (fără glyph-ul nou) va vedea acea iconiță nouă invizibilă
  // la nesfârșit (butonul tot funcționează - doar glyph-ul lipsește din
  // fontul cache-uit), fără nicio eroare vizibilă. Deci ETag+revalidare
  // pentru TOATE fișierele, nu doar cele din afara /assets/.
  const serve = (data, contentType) => {
    const etag = `"${crypto.createHash('sha1').update(data).digest('hex')}"`;
    const headers = {
      'Content-Type': contentType,
      'Cache-Control': 'no-cache, must-revalidate',
      'ETag': etag,
    };

    if (req.headers['if-none-match'] === etag) {
      res.writeHead(304, headers);
      res.end();
      return;
    }
    res.writeHead(200, headers);
    res.end(data);
  };

  fs.readFile(filePath, (err, data) => {
    if (err) {
      fs.readFile(path.join(root, 'index.html'), (err2, indexData) => {
        if (err2) {
          res.writeHead(404);
          res.end('Not found');
          return;
        }
        serve(indexData, 'text/html');
      });
      return;
    }
    const ext = path.extname(filePath);
    serve(data, mime[ext] || 'application/octet-stream');
  });
}).listen(port, '127.0.0.1', () => {
  console.log(`Static server running at http://127.0.0.1:${port}`);
});
