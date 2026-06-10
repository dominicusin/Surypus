const CACHE = 'surypus-v2';
const STATIC = ['/', '/index.html', '/offline.html', '/css/style.css', '/js/app.js', '/js/api.js'];
const DB_NAME = 'surypus-offline';
const DB_VERSION = 1;

// Install: cache static assets
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(STATIC)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  e.waitUntil(clients.claim());
});

// Push: receive and display notifications
self.addEventListener('push', e => {
  const data = e.data ? e.data.json() : {};
  const title = data.title || 'Surypus ERP';
  const body = data.body || '';
  const icon = data.icon || '/manifest.json';
  e.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 192 192\'%3E%3Crect width=\'192\' height=\'192\' rx=\'32\' fill=\'%231976D2\'/%3E%3Ctext x=\'96\' y=\'130\' font-size=\'96\' text-anchor=\'middle\' fill=\'white\' font-family=\'sans-serif\'%3ES%3C/text%3E%3C/svg%3E',
      badge: 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 192 192\'%3E%3Crect width=\'192\' height=\'192\' rx=\'32\' fill=\'%231976D2\'/%3E%3Ctext x=\'96\' y=\'130\' font-size=\'96\' text-anchor=\'middle\' fill=\'white\' font-family=\'sans-serif\'%3ES%3C/text%3E%3C/svg%3E',
      vibrate: [200, 100, 200],
      data: data.data || {}
    })
  );
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  const urlToOpen = e.notification.data?.url || '/';
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
      for (const client of clients) {
        if (client.url.includes(urlToOpen) && 'focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow(urlToOpen);
    })
  );
});

// Fetch: network-first for API, cache-first for static, offline.html for navigation
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (url.pathname.startsWith('/api/')) {
    e.respondWith(networkFirstWithIDB(e.request));
  } else if (e.request.mode === 'navigate') {
    e.respondWith(networkFirstWithFallback(e.request));
  } else {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
  }
});

async function networkFirstWithFallback(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    const cached = await caches.match(request);
    return cached || caches.match('/offline.html');
  }
}

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = e => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('api-cache')) {
        db.createObjectStore('api-cache', { keyPath: 'url' });
      }
    };
    req.onsuccess = e => resolve(e.target.result);
    req.onerror = () => reject(req.error);
  });
}

async function networkFirstWithIDB(request) {
  try {
    const response = await fetch(request);
    if (response.ok && request.method === 'GET') {
      const db = await openDB();
      const data = await response.clone().json().catch(() => null);
      if (data) {
        const tx = db.transaction('api-cache', 'readwrite');
        tx.objectStore('api-cache').put({ url: request.url, data, ts: Date.now() });
      }
    }
    return response;
  } catch {
    const db = await openDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('api-cache', 'readonly');
      const req = tx.objectStore('api-cache').get(request.url);
      req.onsuccess = () => {
        if (req.result) {
          resolve(new Response(JSON.stringify(req.result.data), {
            headers: { 'Content-Type': 'application/json', 'X-Offline': '1' }
          }));
        } else {
          reject(new Error('No cached data'));
        }
      };
      req.onerror = () => reject(req.error);
    });
  }
}
