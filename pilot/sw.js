const CACHE = 'zivlo-pilot-shell-v1';
const ASSETS = [
  './',
  './index.html',
  './styles.css',
  './icon.svg',
  './app.webmanifest',
  './src/app.js',
  './src/domain.js',
  './src/storage.js',
];
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(ASSETS))
      .then(() => self.skipWaiting()),
  );
});
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((k) => k.startsWith('zivlo-pilot-shell-') && k !== CACHE)
            .map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (
          response.ok &&
          ASSETS.some((path) => new URL(path, self.registration.scope).pathname === url.pathname)
        ) {
          const clone = response.clone();
          event.waitUntil(caches.open(CACHE).then((cache) => cache.put(event.request, clone)));
        }
        return response;
      })
      .catch(async () => {
        const cached = await caches.match(event.request);
        if (cached) return cached;
        if (event.request.mode === 'navigate')
          return (
            (await caches.match(new URL('./index.html', self.registration.scope).href)) ??
            Response.error()
          );
        return Response.error();
      }),
  );
});
