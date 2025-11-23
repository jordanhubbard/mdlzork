/**
 * Service Worker for MDL Zork PWA
 * Handles offline caching and asset management
 */

const CACHE_NAME = 'mdlzork-v1.0.0';
const RUNTIME_CACHE = 'mdlzork-runtime';

// Assets to cache on install
const PRECACHE_ASSETS = [
    '/web/',
    '/web/index.html',
    '/web/style.css',
    '/web/app.js',
    '/web/manifest.json',
    '/web/icon.svg',
    // xterm.js from CDN
    'https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js',
    'https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.min.css',
    'https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.min.js'
];

// WASM files (large, cached separately - skip for now as they're huge)
const WASM_ASSETS = [
    // Don't pre-cache these - they're 16MB+
    // '/web/mdli.js',
    // '/web/mdli.wasm',
    // '/web/mdli.data'
];

// Install event - cache assets
self.addEventListener('install', (event) => {
    console.log('[SW] Installing service worker...');
    
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            console.log('[SW] Caching app shell');
            return cache.addAll(PRECACHE_ASSETS);
        }).then(() => {
            // Pre-cache WASM files separately (they're large)
            return caches.open(RUNTIME_CACHE).then((cache) => {
                console.log('[SW] Caching WASM files');
                return cache.addAll(WASM_ASSETS).catch((err) => {
                    console.warn('[SW] Failed to cache some WASM files:', err);
                    // Don't fail installation if WASM caching fails
                });
            });
        }).then(() => {
            console.log('[SW] Installation complete');
            // Force activation
            return self.skipWaiting();
        })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('[SW] Activating service worker...');
    
    event.waitUntil(
        caches.keys().then((cacheNames) => {
            return Promise.all(
                cacheNames.map((cacheName) => {
                    if (cacheName !== CACHE_NAME && cacheName !== RUNTIME_CACHE) {
                        console.log('[SW] Deleting old cache:', cacheName);
                        return caches.delete(cacheName);
                    }
                })
            );
        }).then(() => {
            console.log('[SW] Activation complete');
            // Take control of all clients
            return self.clients.claim();
        })
    );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);
    
    // Skip cross-origin requests we don't control
    if (url.origin !== location.origin && !url.hostname.includes('cdn.jsdelivr.net')) {
        return;
    }
    
    // For HTML requests, use network-first strategy
    if (request.headers.get('accept').includes('text/html')) {
        event.respondWith(
            fetch(request)
                .then((response) => {
                    // Cache successful responses
                    const responseClone = response.clone();
                    caches.open(RUNTIME_CACHE).then((cache) => {
                        cache.put(request, responseClone);
                    });
                    return response;
                })
                .catch(() => {
                    // Network failed, try cache
                    return caches.match(request).then((cachedResponse) => {
                        if (cachedResponse) {
                            return cachedResponse;
                        }
                        // Return offline page as last resort
                        return caches.match('/offline.html');
                    });
                })
        );
        return;
    }
    
    // For WASM/JS files, use cache-first strategy
    if (request.url.includes('.wasm') || 
        request.url.includes('.data') ||
        request.url.includes('mdli.js')) {
        event.respondWith(
            caches.match(request).then((cachedResponse) => {
                if (cachedResponse) {
                    console.log('[SW] Serving from cache:', request.url);
                    return cachedResponse;
                }
                
                // Not in cache, fetch and cache it
                return fetch(request).then((response) => {
                    // Only cache successful responses
                    if (response.status === 200) {
                        const responseClone = response.clone();
                        caches.open(RUNTIME_CACHE).then((cache) => {
                            cache.put(request, responseClone);
                        });
                    }
                    return response;
                });
            })
        );
        return;
    }
    
    // For everything else, use cache-first with network fallback
    event.respondWith(
        caches.match(request).then((cachedResponse) => {
            if (cachedResponse) {
                return cachedResponse;
            }
            
            return fetch(request).then((response) => {
                // Cache successful GET requests
                if (request.method === 'GET' && response.status === 200) {
                    const responseClone = response.clone();
                    caches.open(RUNTIME_CACHE).then((cache) => {
                        cache.put(request, responseClone);
                    });
                }
                return response;
            });
        })
    );
});

// Handle messages from clients
self.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }
    
    if (event.data && event.data.type === 'CLEAR_CACHE') {
        event.waitUntil(
            caches.keys().then((cacheNames) => {
                return Promise.all(
                    cacheNames.map((cacheName) => caches.delete(cacheName))
                );
            }).then(() => {
                event.ports[0].postMessage({ success: true });
            })
        );
    }
});

console.log('[SW] Service worker loaded');
