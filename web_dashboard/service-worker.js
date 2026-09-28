// Skyblue — Service Worker : PWA + Web Push
//
// Deux rôles :
//   1) Rendre la page "installable" (mini-cache pour ouvrir hors ligne)
//   2) Recevoir les notifications push envoyées par l'Edge Function
//      Supabase (alertes stock bas, etc.)

// ⚠️ À INCRÉMENTER À CHAQUE CHANGEMENT DE index.html OU app.js.
// L'activation ne purge que les caches dont le nom diffère : sans
// nouveau numéro, les appareils qui ont déjà installé la PWA
// continuent de servir l'ancienne version depuis leur cache, et la
// mise en ligne n'a aucun effet visible.
// v2 — refonte de l'interface (15 sept. 2026).
// v3 — passe de soin : couleurs unifiées, emoji retirés, chiffres
//      alignés (16 sept. 2026).
const CACHE = 'skyblue-v7';
const CORE = [
  './',
  './index.html',
  './app.js',
  './config.js',
  // Le portail technique. Mis en cache comme le reste : on le consulte
  // justement quand quelque chose ne va pas, et une connexion instable
  // est le moment où on en a le plus besoin.
  './portail.html',
  './portail.js',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))),
      )
      .then(() => self.clients.claim()),
  );
});

// Stratégie network-first pour rester frais quand il y a du réseau,
// fallback cache sinon. Le SW ne cache jamais les appels Supabase (le
// dashboard reste toujours "temps réel" quand il est ouvert).
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.hostname.endsWith('supabase.co')) return; // laisse passer
  event.respondWith(
    fetch(req)
      .then((res) => {
        // Copie dans le cache pour un fallback ultérieur.
        const clone = res.clone();
        caches.open(CACHE).then((c) => c.put(req, clone));
        return res;
      })
      .catch(() => caches.match(req)),
  );
});

// ── Push : réception d'une notification depuis le serveur ──────────────
self.addEventListener('push', (event) => {
  let payload = { title: 'Skyblue', body: 'Nouvelle notification' };
  try {
    if (event.data) {
      const t = event.data.text();
      try {
        payload = JSON.parse(t);
      } catch (_) {
        payload.body = t;
      }
    }
  } catch (_) {
    /* ignore */
  }
  const title = payload.title || 'Skyblue';
  const options = {
    body: payload.body || '',
    icon: './icons/icon-192.png',
    badge: './icons/icon-192.png',
    tag: payload.tag || 'skyblue',
    renotify: true,
    data: { url: payload.url || './index.html' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

// Clic sur la notification → ouvre le dashboard (ou focus l'onglet).
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || './index.html';
  event.waitUntil(
    (async () => {
      const list = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true,
      });
      for (const c of list) {
        if ('focus' in c) return c.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    })(),
  );
});
