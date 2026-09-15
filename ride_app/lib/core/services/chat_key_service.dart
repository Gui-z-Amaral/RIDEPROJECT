import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_crypto.dart';

/// Gerencia as chaves do E2EE do chat, **por dispositivo**:
///  - cada aparelho tem seu próprio par; a privada nunca sai dele
///    (secure storage → Keystore/Keychain; no navegador, o storage da origem);
///  - a pública é publicada em `user_keys` junto com um `device_id`;
///  - ao enviar, a mensagem vira um **envelope**: uma cópia cifrada para cada
///    dispositivo do destinatário e para os outros dispositivos do remetente.
///
/// Por que assim: antes havia UMA chave por usuário. Ao logar em outro
/// dispositivo (ex.: a web), o app gerava um par novo e sobrescrevia a pública
/// — o aparelho anterior parava de decifrar tudo ("último que logou ganha").
///
/// Limitação inerente ao E2EE: um dispositivo **novo** não lê mensagens
/// enviadas antes de ele existir (ninguém cifrou para ele).
///
/// A criptografia em si fica em [ChatCrypto] (pura/testável); aqui é o I/O.
class ChatKeyService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _privKeyStorageKey = 'chat_private_key_v1';
  static const _deviceIdStorageKey = 'chat_device_id_v1';

  /// Marcador exibido quando a mensagem não pode ser aberta neste aparelho.
  static const lockedMarker = '🔒 Mensagem cifrada';

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // Cache em memória.
  static String? _privateKey;
  static String? _deviceId;
  // Chave pública por dispositivo: "userId:deviceId" → publicKey.
  // Pode ser cacheada para sempre: a chave de um dispositivo não muda.
  static final Map<String, String> _devicePublicCache = {};

  // ── Identidade deste aparelho ───────────────────────────────

  static Future<String> _myDeviceId() async {
    var id = _deviceId ?? await _storage.read(key: _deviceIdStorageKey);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = List.generate(16, (_) => rnd.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await _storage.write(key: _deviceIdStorageKey, value: id);
    }
    _deviceId = id;
    return id;
  }

  static Future<String?> _myPrivateKey() async {
    _privateKey ??= await _storage.read(key: _privKeyStorageKey);
    return _privateKey;
  }

  /// Garante que ESTE aparelho tem par de chaves e que a pública está
  /// publicada com o seu device_id. Idempotente — chamar no login e no restart.
  static Future<void> ensureKeys() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final deviceId = await _myDeviceId();
      var priv = await _storage.read(key: _privKeyStorageKey);
      String pub;
      if (priv == null) {
        final kp = await ChatCrypto.generateKeyPair();
        priv = kp.privateKey;
        pub = kp.publicKey;
        await _storage.write(key: _privKeyStorageKey, value: priv);
      } else {
        pub = await ChatCrypto.publicFromPrivate(priv);
      }
      _privateKey = priv;
      await _db.from('user_keys').upsert({
        'user_id': uid,
        'device_id': deviceId,
        'public_key': pub,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_id');
    } catch (_) {
      // best-effort — o envio/leitura tratam o erro adiante
    }
  }

  // ── Chaves dos dispositivos ─────────────────────────────────

  /// Todos os dispositivos de [userId] (busca sempre fresca: um aparelho novo
  /// do contato precisa entrar nos envelopes já na próxima mensagem).
  static Future<List<({String deviceId, String publicKey})>> _devicesOf(
      String userId) async {
    final rows = await _db
        .from('user_keys')
        .select('device_id, public_key')
        .eq('user_id', userId);

    final list = <({String deviceId, String publicKey})>[];
    for (final r in (rows as List)) {
      final m = r as Map<String, dynamic>;
      final d = m['device_id'] as String?;
      final p = m['public_key'] as String?;
      if (d == null || p == null) continue;
      _devicePublicCache['$userId:$d'] = p;
      list.add((deviceId: d, publicKey: p));
    }
    return list;
  }

  /// Pública de um dispositivo específico (cacheada — não muda).
  static Future<String?> _devicePublicKey(
      String userId, String deviceId) async {
    final cached = _devicePublicCache['$userId:$deviceId'];
    if (cached != null) return cached;
    final row = await _db
        .from('user_keys')
        .select('public_key')
        .eq('user_id', userId)
        .eq('device_id', deviceId)
        .maybeSingle();
    final pub = row?['public_key'] as String?;
    if (pub != null) _devicePublicCache['$userId:$deviceId'] = pub;
    return pub;
  }

  // ── Envelope (formato puro, testável) ───────────────────────

  /// Serializa o envelope: quem enviou (dispositivo) + uma cópia cifrada por
  /// dispositivo destinatário.
  @visibleForTesting
  static String buildEnvelope(
          String senderDevice, Map<String, String> envelopes) =>
      jsonEncode({'v': 2, 'sd': senderDevice, 'e': envelopes});

  /// Lê o envelope e devolve o dispositivo remetente e a cópia destinada a
  /// [myDevice]. Retorna `null` se não for um envelope v2 válido, e `cipher`
  /// nulo quando não há cópia para este aparelho (cadastrado depois do envio).
  @visibleForTesting
  static ({String senderDevice, String? cipher})? parseEnvelope(
      String packed, String myDevice) {
    try {
      final decoded = jsonDecode(packed);
      if (decoded is! Map || decoded['v'] != 2) return null;
      final sd = decoded['sd'];
      final e = decoded['e'];
      if (sd is! String || e is! Map) return null;
      return (senderDevice: sd, cipher: e[myDevice] as String?);
    } catch (_) {
      return null;
    }
  }

  // ── Envelope ────────────────────────────────────────────────

  /// Cifra [plaintext] para a conversa com [otherUserId], gerando um envelope
  /// com uma cópia para cada dispositivo do contato **e** dos meus outros
  /// aparelhos (senão eu não leria no PC o que mandei do celular).
  static Future<String> encryptFor(String otherUserId, String plaintext) async {
    final uid = _uid;
    final priv = await _myPrivateKey();
    if (uid == null || priv == null) {
      throw StateError('Chave local ausente — reabra o app.');
    }
    final myDevice = await _myDeviceId();

    final peers = await _devicesOf(otherUserId);
    if (peers.isEmpty) {
      throw StateError('O contato ainda não ativou o chat seguro.');
    }
    final mine = await _devicesOf(uid);

    final envelopes = <String, String>{};
    for (final d in [...peers, ...mine]) {
      if (envelopes.containsKey(d.deviceId)) continue;
      envelopes[d.deviceId] = await ChatCrypto.encrypt(
        myPrivateKey: priv,
        peerPublicKey: d.publicKey,
        plaintext: plaintext,
      );
    }

    return buildEnvelope(myDevice, envelopes);
  }

  /// Decifra uma mensagem enviada por [senderUserId]. Nunca lança: em caso de
  /// falha devolve [lockedMarker], pra não quebrar a lista de mensagens.
  static Future<String> decryptFrom(String senderUserId, String packed) async {
    if (packed.isEmpty) return '';
    try {
      final priv = await _myPrivateKey();
      if (priv == null) return lockedMarker;

      final myDevice = await _myDeviceId();
      // null = formato antigo (pré multi-dispositivo) ou inválido.
      final env = parseEnvelope(packed, myDevice);
      if (env == null) return lockedMarker;

      // Aparelho cadastrado depois do envio: ninguém cifrou para ele.
      final mine = env.cipher;
      if (mine == null) return lockedMarker;

      final senderPub =
          await _devicePublicKey(senderUserId, env.senderDevice);
      if (senderPub == null) return lockedMarker;

      return await ChatCrypto.decrypt(
        myPrivateKey: priv,
        peerPublicKey: senderPub,
        packed: mine,
      );
    } catch (_) {
      return lockedMarker;
    }
  }

  /// Limpa o cache em memória (logout). A chave privada e o device_id
  /// permanecem no storage — é o que permite reler o histórico ao logar de
  /// novo no mesmo aparelho.
  static void clearCache() {
    _privateKey = null;
    _devicePublicCache.clear();
  }
}
