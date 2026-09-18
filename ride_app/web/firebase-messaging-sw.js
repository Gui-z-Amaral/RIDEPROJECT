// Service worker do Firebase Cloud Messaging.
//
// É ele quem exibe a notificação quando o PWA está FECHADO ou em segundo
// plano. Com o app aberto, nada acontece aqui: a própria lista de notificações
// do app já se atualiza pelo realtime do Supabase (ver PushNotificationService).
//
// Precisa ficar na raiz do site (web/ vira a raiz no build) e com este nome
// exato — é onde o firebase_messaging_web procura.
//
// A config abaixo é a mesma de lib/core/constants/firebase_web_config.dart.
// São valores públicos (vão no JS de qualquer app web com Firebase).

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDdZPkvQurCl8haLW2KtzTsFdaxd_VRLmc',
  authDomain: 'rideapp-a.firebaseapp.com',
  projectId: 'rideapp-a',
  storageBucket: 'rideapp-a.firebasestorage.app',
  messagingSenderId: '984419643137',
  appId: '1:984419643137:web:55f67fbcb925e090347500',
});

// Só inicializar já basta: quando a mensagem traz o bloco `notification` (é o
// caso do nosso worker na VPS), o FCM exibe sozinho. Registrar um
// onBackgroundMessage que também chamasse showNotification faria a notificação
// aparecer DUAS vezes — por isso não fazemos isso aqui.
firebase.messaging();

// Toque na notificação: leva o usuário para a tela certa.
//
// Antes isto focava uma aba (sem navegar) ou abria a raiz — por isso o push
// sempre caía na tela de início, fosse mensagem, convite ou evento.
//
// O destino NÃO é calculado aqui de propósito. O mapeamento de
// (type, payload) → rota vive em lib/core/utils/notification_router.dart, e
// tê-lo em dois lugares garantiria que um dia os dois discordassem. Aqui só
// repassamos os dados crus para a rota /n, que resolve no Dart.
self.addEventListener('notificationclick', function (event) {
  event.notification.close();

  // O FCM ora entrega os dados direto, ora embrulhados em FCM_MSG.
  var d = event.notification.data || {};
  if (d.FCM_MSG && d.FCM_MSG.data) d = d.FCM_MSG.data;

  var url = '/n?t=' + encodeURIComponent(d.type || '') +
            '&p=' + encodeURIComponent(d.payload || '{}');

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (list) {
        for (var i = 0; i < list.length; i++) {
          var c = list[i];
          // navigate() move a aba já aberta para o destino. Só focar deixava
          // o usuário olhando a tela em que ele já estava.
          if ('navigate' in c && 'focus' in c) {
            return c.navigate(url).then(function (nc) {
              return (nc || c).focus();
            }).catch(function () { return c.focus(); });
          }
        }
        if (clients.openWindow) return clients.openWindow(url);
      })
  );
});
