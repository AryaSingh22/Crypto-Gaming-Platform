// GameFi Platform Service Worker
// Provides offline functionality, background sync, and push notifications

const CACHE_NAME = 'gamefi-v1.0.0';
const STATIC_CACHE = 'gamefi-static-v1.0.0';
const DYNAMIC_CACHE = 'gamefi-dynamic-v1.0.0';

// Static assets to cache immediately
const STATIC_ASSETS = [
  '/',
  '/games',
  '/marketplace',
  '/staking',
  '/social',
  '/dashboard',
  '/offline',
  '/manifest.json',
  '/icons/icon-192x192.png',
  '/icons/icon-512x512.png',
  // Core CSS and JS files would be added here
];

// API endpoints to cache
const API_CACHE_PATTERNS = [
  /\/api\/games\//,
  /\/api\/nft\//,
  /\/api\/user\//,
  /\/api\/social\//
];

// Blockchain data that changes frequently - don't cache
const NO_CACHE_PATTERNS = [
  /\/api\/realtime\//,
  /\/api\/websocket\//,
  /\/api\/transactions\//,
  /\/api\/live\//
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[ServiceWorker] Install event');
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[ServiceWorker] Pre-caching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[ServiceWorker] Static assets cached successfully');
        return self.skipWaiting();
      })
      .catch((error) => {
        console.error('[ServiceWorker] Failed to cache static assets:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[ServiceWorker] Activate event');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
              console.log('[ServiceWorker] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('[ServiceWorker] Old caches cleaned up');
        return self.clients.claim();
      })
  );
});

// Fetch event - implement caching strategy
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip Chrome extension requests
  if (url.protocol === 'chrome-extension:') {
    return;
  }

  // Handle different types of requests
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(handleAPIRequest(request));
  } else if (url.pathname.startsWith('/_next/static/')) {
    event.respondWith(handleStaticAssets(request));
  } else {
    event.respondWith(handlePageRequest(request));
  }
});

// Handle API requests with network-first strategy
async function handleAPIRequest(request) {
  const url = new URL(request.url);
  
  // Don't cache real-time endpoints
  if (NO_CACHE_PATTERNS.some(pattern => pattern.test(url.pathname))) {
    return fetch(request).catch(() => {
      return new Response(JSON.stringify({ 
        error: 'Network unavailable', 
        offline: true 
      }), {
        status: 503,
        headers: { 'Content-Type': 'application/json' }
      });
    });
  }

  try {
    // Try network first
    const networkResponse = await fetch(request);
    
    // Cache successful responses for API endpoints
    if (networkResponse.ok && API_CACHE_PATTERNS.some(pattern => pattern.test(url.pathname))) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    
    return networkResponse;
  } catch (error) {
    // Fall back to cache
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    
    // Return offline response
    return new Response(JSON.stringify({ 
      error: 'Network unavailable', 
      offline: true 
    }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// Handle static assets with cache-first strategy
async function handleStaticAssets(request) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }

  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[ServiceWorker] Failed to fetch static asset:', error);
    throw error;
  }
}

// Handle page requests with stale-while-revalidate strategy
async function handlePageRequest(request) {
  const cachedResponse = await caches.match(request);
  
  const fetchPromise = fetch(request)
    .then((networkResponse) => {
      if (networkResponse.ok) {
        const cache = caches.open(DYNAMIC_CACHE);
        cache.then(c => c.put(request, networkResponse.clone()));
      }
      return networkResponse;
    })
    .catch(() => {
      // If network fails and we have no cache, return offline page
      if (!cachedResponse) {
        return caches.match('/offline');
      }
    });

  return cachedResponse || fetchPromise;
}

// Background sync for offline actions
self.addEventListener('sync', (event) => {
  console.log('[ServiceWorker] Background sync:', event.tag);
  
  if (event.tag === 'background-sync-transactions') {
    event.waitUntil(syncPendingTransactions());
  } else if (event.tag === 'background-sync-social') {
    event.waitUntil(syncSocialActions());
  }
});

// Sync pending blockchain transactions
async function syncPendingTransactions() {
  console.log('[ServiceWorker] Syncing pending transactions');
  
  try {
    // Get pending transactions from IndexedDB
    const pendingTxs = await getPendingTransactions();
    
    for (const tx of pendingTxs) {
      try {
        const response = await fetch('/api/transactions/submit', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(tx)
        });
        
        if (response.ok) {
          await removePendingTransaction(tx.id);
          console.log('[ServiceWorker] Transaction synced:', tx.id);
        }
      } catch (error) {
        console.error('[ServiceWorker] Failed to sync transaction:', error);
      }
    }
  } catch (error) {
    console.error('[ServiceWorker] Failed to sync transactions:', error);
  }
}

// Sync social actions (messages, likes, follows)
async function syncSocialActions() {
  console.log('[ServiceWorker] Syncing social actions');
  
  try {
    const pendingActions = await getPendingSocialActions();
    
    for (const action of pendingActions) {
      try {
        const response = await fetch('/api/social/sync', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(action)
        });
        
        if (response.ok) {
          await removePendingSocialAction(action.id);
          console.log('[ServiceWorker] Social action synced:', action.id);
        }
      } catch (error) {
        console.error('[ServiceWorker] Failed to sync social action:', error);
      }
    }
  } catch (error) {
    console.error('[ServiceWorker] Failed to sync social actions:', error);
  }
}

// Push notification handling
self.addEventListener('push', (event) => {
  console.log('[ServiceWorker] Push received');
  
  const options = {
    body: 'You have new activity in GameFi Platform!',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/badge-72x72.png',
    vibrate: [100, 50, 100],
    data: {
      dateOfArrival: Date.now(),
      primaryKey: 1
    },
    actions: [
      {
        action: 'explore',
        title: 'View Activity',
        icon: '/icons/action-explore.png'
      },
      {
        action: 'close',
        title: 'Close',
        icon: '/icons/action-close.png'
      }
    ]
  };

  if (event.data) {
    const data = event.data.json();
    options.body = data.body || options.body;
    options.title = data.title || 'GameFi Platform';
    options.data = { ...options.data, ...data };
  }

  event.waitUntil(
    self.registration.showNotification('GameFi Platform', options)
  );
});

// Notification click handling
self.addEventListener('notificationclick', (event) => {
  console.log('[ServiceWorker] Notification click received');
  
  event.notification.close();

  if (event.action === 'explore') {
    event.waitUntil(
      clients.openWindow('/dashboard')
    );
  } else if (event.action === 'close') {
    // Just close the notification
    return;
  } else {
    // Default action - open the app
    event.waitUntil(
      clients.matchAll().then((clients) => {
        if (clients.length > 0) {
          return clients[0].focus();
        } else {
          return clients.openWindow('/');
        }
      })
    );
  }
});

// Message handling for communication with main thread
self.addEventListener('message', (event) => {
  console.log('[ServiceWorker] Message received:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  } else if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(DYNAMIC_CACHE).then((cache) => {
        return cache.addAll(event.data.payload);
      })
    );
  }
});

// IndexedDB helper functions for offline storage
async function getPendingTransactions() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('GameFiOfflineDB', 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction(['pendingTransactions'], 'readonly');
      const store = transaction.objectStore('pendingTransactions');
      const getAllRequest = store.getAll();
      
      getAllRequest.onsuccess = () => resolve(getAllRequest.result);
      getAllRequest.onerror = () => reject(getAllRequest.error);
    };
    
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      if (!db.objectStoreNames.contains('pendingTransactions')) {
        db.createObjectStore('pendingTransactions', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('pendingSocialActions')) {
        db.createObjectStore('pendingSocialActions', { keyPath: 'id' });
      }
    };
  });
}

async function getPendingSocialActions() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('GameFiOfflineDB', 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction(['pendingSocialActions'], 'readonly');
      const store = transaction.objectStore('pendingSocialActions');
      const getAllRequest = store.getAll();
      
      getAllRequest.onsuccess = () => resolve(getAllRequest.result);
      getAllRequest.onerror = () => reject(getAllRequest.error);
    };
  });
}

async function removePendingTransaction(id) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('GameFiOfflineDB', 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction(['pendingTransactions'], 'readwrite');
      const store = transaction.objectStore('pendingTransactions');
      const deleteRequest = store.delete(id);
      
      deleteRequest.onsuccess = () => resolve();
      deleteRequest.onerror = () => reject(deleteRequest.error);
    };
  });
}

async function removePendingSocialAction(id) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('GameFiOfflineDB', 1);
    
    request.onerror = () => reject(request.error);
    request.onsuccess = () => {
      const db = request.result;
      const transaction = db.transaction(['pendingSocialActions'], 'readwrite');
      const store = transaction.objectStore('pendingSocialActions');
      const deleteRequest = store.delete(id);
      
      deleteRequest.onsuccess = () => resolve();
      deleteRequest.onerror = () => reject(deleteRequest.error);
    };
  });
}

// Periodic background tasks
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'cache-cleanup') {
    event.waitUntil(cleanupCache());
  } else if (event.tag === 'data-sync') {
    event.waitUntil(syncOfflineData());
  }
});

async function cleanupCache() {
  console.log('[ServiceWorker] Cleaning up cache');
  
  const cache = await caches.open(DYNAMIC_CACHE);
  const requests = await cache.keys();
  
  // Remove cache entries older than 7 days
  const oneWeekAgo = Date.now() - (7 * 24 * 60 * 60 * 1000);
  
  for (const request of requests) {
    const response = await cache.match(request);
    const dateHeader = response.headers.get('date');
    
    if (dateHeader) {
      const cacheDate = new Date(dateHeader).getTime();
      if (cacheDate < oneWeekAgo) {
        await cache.delete(request);
        console.log('[ServiceWorker] Removed expired cache entry:', request.url);
      }
    }
  }
}

async function syncOfflineData() {
  console.log('[ServiceWorker] Syncing offline data');
  
  // Sync pending transactions and social actions
  await Promise.all([
    syncPendingTransactions(),
    syncSocialActions()
  ]);
}

console.log('[ServiceWorker] Service worker loaded successfully');