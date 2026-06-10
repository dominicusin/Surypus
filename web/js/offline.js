// Surypus - Offline Storage & Sync Queue

const DB_NAME = 'surypus-offline';
const DB_VERSION = 2;

function openDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = e => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('api-cache')) {
        db.createObjectStore('api-cache', { keyPath: 'url' });
      }
      if (!db.objectStoreNames.contains('sync-queue')) {
        const store = db.createObjectStore('sync-queue', { keyPath: 'id', autoIncrement: true });
        store.createIndex('status', 'status', { unique: false });
      }
    };
    req.onsuccess = e => resolve(e.target.result);
    req.onerror = () => reject(req.error);
  });
}

function updateOnlineStatus() {
  const el = document.getElementById('offline-status');
  if (!el) return;
  const online = navigator.onLine;
  el.className = 'offline-indicator ' + (online ? 'online' : 'offline');
  el.querySelector('.offline-text').textContent = online ? 'Online' : 'Offline';
}

async function enqueueMutation(url, method, body) {
  const db = await openDB();
  const tx = db.transaction('sync-queue', 'readwrite');
  tx.objectStore('sync-queue').add({ url, method, body, ts: Date.now(), status: 'pending' });
  updateQueueCount();
}

async function getQueueCount() {
  const db = await openDB();
  const tx = db.transaction('sync-queue', 'readonly');
  const count = tx.objectStore('sync-queue').count();
  return new Promise((resolve, reject) => {
    count.onsuccess = () => resolve(count.result);
    count.onerror = () => reject(count.error);
  });
}

async function updateQueueCount() {
  const el = document.getElementById('offline-status');
  if (!el) return;
  const count = await getQueueCount();
  const text = el.querySelector('.offline-text');
  if (count > 0) {
    text.textContent = count + ' ожидает';
    el.className = 'offline-indicator pending';
  } else {
    text.textContent = 'Online';
    el.className = 'offline-indicator online';
  }
}

async function syncQueue() {
  const db = await openDB();
  const tx = db.transaction('sync-queue', 'readonly');
  const store = tx.objectStore('sync-queue');
  const index = store.index('status');
  const items = index.getAll('pending');

  items.onsuccess = async () => {
    for (const item of items.result) {
      try {
        const cfg = {
          method: item.method,
          url: item.url,
          headers: { 'Content-Type': 'application/json' },
          data: item.body ? JSON.stringify(item.body) : undefined
        };
        if (window.authToken) {
          cfg.headers.Authorization = 'Bearer ' + window.authToken;
        }
        await axios(cfg);
        const db2 = await openDB();
        const tx2 = db2.transaction('sync-queue', 'readwrite');
        tx2.objectStore('sync-queue').delete(item.id);
      } catch (err) {
        console.error('Sync failed for', item.url, err);
      }
    }
    updateQueueCount();
  };
}

// Intercept axios requests for offline queuing
const origRequest = axios.interceptors.request;
axios.interceptors.request.use(function(config) {
  if (!navigator.onLine && config.method !== 'get') {
    enqueueMutation(config.url, config.method, config.data);
    return Promise.reject({ __offline_queued: true, config });
  }
  return config;
});

// Handle offline-queued responses silently
axios.interceptors.response.use(
  function(response) { return response; },
  function(error) {
    if (error.__offline_queued) {
      return Promise.resolve({ data: { offline: true, queued: true }, status: 202 });
    }
    return Promise.reject(error);
  }
);

// Listeners
window.addEventListener('online', () => { updateOnlineStatus(); syncQueue(); });
window.addEventListener('offline', updateOnlineStatus);

// Push notifications
const VAPID_PUBLIC_KEY = null; // Set via backend config when available

async function subscribePush() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;
  try {
    const reg = await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: VAPID_PUBLIC_KEY
    });
    const authToken = localStorage.getItem('surypus_token');
    if (authToken) {
      const subJSON = sub.toJSON();
      await axios.post('/api/v1/notifications/push/subscribe', {
        psrEndpoint: subJSON.endpoint,
        psrP256dh: arrayBufToBase64(subJSON.keys.p256dh),
        psrAuth: arrayBufToBase64(subJSON.keys.auth)
      }, { headers: { Authorization: 'Bearer ' + authToken } });
    }
  } catch (err) {
    console.log('Push subscription deferred (no VAPID key yet):', err.message);
  }
}

async function unsubscribePush() {
  try {
    const reg = await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.getSubscription();
    if (sub) await sub.unsubscribe();
    const authToken = localStorage.getItem('surypus_token');
    if (authToken) {
      await axios.post('/api/v1/notifications/push/unsubscribe', {},
        { headers: { Authorization: 'Bearer ' + authToken } });
    }
  } catch (err) {
    console.error('Unsubscribe failed:', err);
  }
}

function arrayBufToBase64(buf) {
  if (!buf) return '';
  const bytes = new Uint8Array(buf);
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

// Push toggle (called from UI)
function togglePush(enabled) {
  if (enabled) subscribePush();
  else unsubscribePush();
}

// Init
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    updateOnlineStatus();
    updateQueueCount();
    // Subscribe to push after a delay to ensure SW is ready
    setTimeout(subscribePush, 5000);
  });
} else {
  updateOnlineStatus();
  updateQueueCount();
  setTimeout(subscribePush, 5000);
}
