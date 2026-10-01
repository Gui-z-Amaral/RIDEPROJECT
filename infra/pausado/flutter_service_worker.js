// Service worker "desligador".
//
// O PWA antigo instalou um service worker com o app inteiro em cache. Sem
// isto, quem tinha o app no celular continuaria abrindo a versão guardada,
// que não conecta mais, em vez de ver o aviso de pausa. O navegador busca este
// arquivo de novo ao checar atualização, encontra esta versão, e ela apaga os
// caches, remove a si mesma e recarrega a aba.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const chaves = await caches.keys();
    await Promise.all(chaves.map((k) => caches.delete(k)));
    await self.registration.unregister();
    const abas = await self.clients.matchAll({ type: 'window' });
    for (const aba of abas) aba.navigate(aba.url);
  })());
});
