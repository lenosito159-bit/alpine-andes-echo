import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, extname, sep } from 'node:path';
import { createHash } from 'node:crypto';
const root = fileURLToPath(new URL('.', import.meta.url));
const port = Number(process.env.PORT || 4173);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.webmanifest': 'application/manifest+json',
};
createServer(async (req, res) => {
  try {
    if (!['GET', 'HEAD'].includes(req.method)) {
      res.writeHead(405);
      res.end();
      return;
    }
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    const path = resolve(root, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (
      !path.startsWith(root.endsWith(sep) ? root : root + sep) ||
      !['.html', '.js', '.css', '.svg', '.webmanifest'].includes(extname(path))
    ) {
      res.writeHead(404);
      res.end();
      return;
    }
    if (!(await stat(path)).isFile()) throw new Error();
    const body = await readFile(path);
    let scriptHashes = '',
      styleHashes = '';
    if (pathname === '/dist/Zivlo-Peru.html') {
      const html = body.toString('utf8');
      const hash = (contents) =>
        `'sha256-${createHash('sha256').update(contents).digest('base64')}'`;
      scriptHashes = [...html.matchAll(/<script type="module">([\s\S]*?)<\/script>/g)]
        .map((m) => hash(m[1]))
        .join(' ');
      styleHashes = [...html.matchAll(/<style>([\s\S]*?)<\/style>/g)]
        .map((m) => hash(m[1]))
        .join(' ');
    }
    res.writeHead(200, {
      'Content-Type': types[extname(path)],
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': `default-src 'self'; script-src 'self' ${scriptHashes}; style-src 'self' ${styleHashes}; img-src 'self' data:; object-src 'none'; base-uri 'self'; frame-ancestors 'none'`,
    });
    res.end(req.method === 'HEAD' ? undefined : body);
  } catch {
    res.writeHead(404);
    res.end('No encontrado');
  }
}).listen(port, '0.0.0.0', () =>
  console.log(`Zivlo iniciado en el puerto ${port}. Abre el navegador en este equipo.`),
);
