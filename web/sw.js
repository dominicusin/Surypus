const CACHE = 'surypus-v1';
const STATIC = ['/', '/index.html', '/css/style.css', '/js/app.js', '/js/api.js'];
const DB_NAME = 'surypus-offline';
const DB_VERSION = 1;

// Install: cache static assets
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(STATIC)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(clients.claim());
});

// Fetch: network-first for API, cache-first for static
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  if (url.pathname.startsWith('/api/')) {
    e.respondWith(networkFirstWithIDB(e.request));
  } else {
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
  }
});

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
    // Offline: serve from IndexedDB
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
