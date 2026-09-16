import 'package:firebase_core/firebase_core.dart';

/// Configuração do Firebase para a **web**.
///
/// No Android o `google-services.json` fornece isso automaticamente; na web é
/// preciso passar as opções na mão para o `Firebase.initializeApp`.
///
/// Estes valores são **públicos por design** — vão embutidos no JavaScript de
/// qualquer app web com Firebase e o próprio Firebase documenta que não são
/// segredo. Quem protege os dados é a RLS do Supabase. (Diferente da chave do
/// Maps, que mantemos em `web/env.js` git-ignored por escolha nossa.)
///
/// Projeto: `rideapp-a` — o MESMO do Android, então o worker de push que já
/// envia para o celular alcança também os tokens web.
class FirebaseWebConfig {
  const FirebaseWebConfig._();

  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyDdZPkvQurCl8haLW2KtzTsFdaxd_VRLmc',
    authDomain: 'rideapp-a.firebaseapp.com',
    projectId: 'rideapp-a',
    storageBucket: 'rideapp-a.firebasestorage.app',
    messagingSenderId: '984419643137',
    appId: '1:984419643137:web:55f67fbcb925e090347500',
    measurementId: 'G-YJ435P6X8J',
  );

  /// Chave **pública** VAPID (Firebase Console → Cloud Messaging →
  /// Certificados push da Web). É ela que autoriza o navegador a se inscrever
  /// no push; a privada correspondente fica no servidor do Firebase.
  ///
  /// Enquanto estiver vazia, o push web é **pulado em silêncio** — o resto do
  /// app continua funcionando normalmente.
  static const String vapidKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue:
        'BNy2KUvuWhpAKMWHfukx7Y7HBwQys9JQikhItKaOGZzeIPln5LGZTeHZh6j3UdfC1vp556P0OyU0U_PqzLIzYWM',
  );

  /// O push web só é possível com a chave configurada.
  static bool get hasVapidKey => vapidKey.isNotEmpty;
}
