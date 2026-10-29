// Guarda a "casca" do app para abrir rápido no celular. Os dados vêm sempre do Supabase (nunca do cache).
const CACHE = "inventario-v4";
const ARQUIVOS = ["./", "index.html", "config.js", "logo-efaz.png", "manifest.webmanifest", "icon-192.png"];

self.addEventListener("install", e => e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARQUIVOS)).then(() => self.skipWaiting())));
self.addEventListener("activate", e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())
));
// Rede primeiro (para pegar sempre a versão nova); cache só quando estiver sem internet.
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return;
  e.respondWith(
    fetch(e.request).then(r => { const copia = r.clone(); caches.open(CACHE).then(c => c.put(e.request, copia)); return r; })
      .catch(() => caches.match(e.request))
  );
});
