import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_crypto.dart';

/// Gerencia as chaves do E2EE do chat:
///  - guarda a chave PRIVADA só no aparelho (secure storage → Keystore/Keychain);
///  - publica/lê a chave PÚBLICA na tabela `user_keys` do Supabase;
///  - expõe cifrar/decifrar por conversa (usa sempre a pública do OUTRO usuário).
///
/// A criptografia em si fica em [ChatCrypto] (pura/testável); aqui é o I/O.
class ChatKeyService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _privKeyStorageKey = 'chat_private_key_v1';

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // Cache em memória: chave privada + públicas dos contatos (por userId).
  static String? _privateKey;
  static final Map<String, String> _peerPublicCache = {};

  /// Garante que o usuário logado tem par de chaves e que a pública está
  /// publicada. Idempotente — chamar no login e no restart.
  static Future<void> ensureKeys() async {
    final uid = _uid;
    if (uid == null) return;
    try {
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
      await _publishPublicKey(uid, pub); // upsert idempotente
    } catch (_) {
      // best-effort — se falhar, o envio/leitura tratam o erro adiante
    }
  }

  static Future<void> _publishPublicKey(String uid, String publicKey) async {
    await _db.from('user_keys').upsert({
      'user_id': uid,
      'public_key': publicKey,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  static Future<String?> _myPrivateKey() async {
    _privateKey ??= await _storage.read(key: _privKeyStorageKey);
    return _privateKey;
  }

  /// Chave pública de [userId] (cacheada). Null se o usuário ainda não publicou.
  static Future<String?> _peerPublicKey(String userId) async {
    final cached = _peerPublicCache[userId];
    if (cached != null) return cached;
    final row = await _db
        .from('user_keys')
        .select('public_key')
        .eq('user_id', userId)
        .maybeSingle();
    final pub = row?['public_key'] as String?;
    if (pub != null) _peerPublicCache[userId] = pub;
    return pub;
  }

  /// Cifra [plaintext] para a conversa com [otherUserId].
  /// Lança se faltar a chave (própria ou do contato).
  static Future<String> encryptFor(String otherUserId, String plaintext) async {
    final priv = await _myPrivateKey();
    final pub = await _peerPublicKey(otherUserId);
    if (priv == null) {
      throw StateError('Chave local ausente — reabra o app.');
    }
    if (pub == null) {
      throw StateError('O contato ainda não ativou o chat seguro.');
    }
    return ChatCrypto.encrypt(
      myPrivateKey: priv,
      peerPublicKey: pub,
      plaintext: plaintext,
    );
  }

  /// Decifra uma mensagem da conversa com [otherUserId]. Nunca lança: em caso
  /// de falha devolve um marcador, pra não quebrar a lista de mensagens.
  static Future<String> decryptFrom(String otherUserId, String packed) async {
    if (packed.isEmpty) return '';
    try {
      final priv = await _myPrivateKey();
      final pub = await _peerPublicKey(otherUserId);
      if (priv == null || pub == null) return '🔒 Mensagem cifrada';
      return await ChatCrypto.decrypt(
        myPrivateKey: priv,
        peerPublicKey: pub,
        packed: packed,
      );
    } catch (_) {
      return '🔒 Mensagem cifrada';
    }
  }

  /// Limpa o cache em memória (logout). A chave privada permanece no secure
  /// storage — é o que permite reler o histórico ao logar de novo no mesmo
  /// aparelho.
  static void clearCache() {
    _privateKey = null;
    _peerPublicCache.clear();
  }
}
