import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_crypto.dart';

/// Gerencia as chaves da cifra do chat, **por conta** (migration 036):
///  - cada usuário tem um par; a pública fica em `user_keys` (legível por quem
///    vai cifrar para ele) e a privada em `user_chat_keys`, **cifrada** e
///    acessível só pelas funções `chat_key_get`/`chat_key_set` (037);
///  - ao enviar, a mensagem vira um **envelope** com duas cópias cifradas: a do
///    destinatário e a minha, para eu reler no PC o que mandei do celular.
///
/// Por que deixou de ser por aparelho: com a chave só no dispositivo, limpar os
/// dados do navegador ou trocar de celular tornava TODO o histórico ilegível, e
/// não havia nada que o usuário pudesse fazer. Num teste real um aparelho gerou
/// três identidades em quatro minutos, e havia 23 chaves para 13 pessoas.
///
/// **Isto NÃO é criptografia ponta a ponta.** A chave privada fica no servidor,
/// então quem tiver acesso ao banco consegue decifrar as mensagens. O que
/// continua valendo: a chave fica cifrada em repouso com um segredo do Vault,
/// cuja chave-mestra vive num arquivo fora do banco — então um backup ou dump
/// vazado, sozinho, é inútil. Não divulgar como "ponta a ponta".
///
/// A criptografia em si fica em [ChatCrypto] (pura/testável); aqui é o I/O.
class ChatKeyService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _privKeyStorageKey = 'chat_private_key_v1';

  /// Marcador exibido quando a mensagem não pode ser aberta.
  static const lockedMarker = '🔒 Mensagem cifrada';

  static SupabaseClient get _db => Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  // Cache em memória.
  static String? _privateKey;

  // Chave pública por usuário. Cacheável para sempre: não muda.
  static final Map<String, String> _publicCache = {};

  // ── Identidade da conta ─────────────────────────────────────

  /// Chave privada desta conta: memória → armazenamento local → servidor.
  ///
  /// O armazenamento local é só cache. A fonte da verdade é o servidor, e é
  /// isso que faz o histórico sobreviver a reinstalar o app ou trocar de
  /// aparelho.
  static Future<String?> _myPrivateKey() async {
    if (_privateKey != null) return _privateKey;
    try {
      _privateKey = await _storage.read(key: _privKeyStorageKey);
    } catch (_) {
      // Armazenamento indisponível (aba privada, storage bloqueado): segue para
      // o servidor, que é justamente o ponto desta mudança.
    }
    if (_privateKey != null) return _privateKey;

    final uid = _uid;
    if (uid == null) return null;
    try {
      // Pela RPC, nao pela tabela: desde a 037 a coluna guarda a chave
      // CIFRADA e a tabela nao e mais acessivel pela API. A funcao decifra e
      // devolve so a chave de quem chama.
      final priv = await _db.rpc('chat_key_get') as String?;
      if (priv != null) {
        _privateKey = priv;
        await _cacheLocally(priv);
      }
      return priv;
    } catch (_) {
      return null;
    }
  }

  /// Guarda a chave no aparelho só para evitar uma ida ao servidor a cada
  /// abertura. Falhar aqui não atrapalha: o servidor continua tendo.
  static Future<void> _cacheLocally(String priv) async {
    try {
      await _storage.write(key: _privKeyStorageKey, value: priv);
    } catch (_) {}
  }

  /// Garante que a conta tem par de chaves publicado. Idempotente — chamar no
  /// login e no restart.
  static Future<void> ensureKeys() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      if (await _myPrivateKey() != null) return;

      final kp = await ChatCrypto.generateKeyPair();
      // Uma chamada so para as duas metades: se a publica entrasse e a privada
      // falhasse, todos cifrariam para uma chave que eu nao consigo abrir.
      // A funcao tambem cifra a privada antes de gravar.
      await _db.rpc('chat_key_set', params: {
        'p_private': kp.privateKey,
        'p_public': kp.publicKey,
      });

      _privateKey = kp.privateKey;
      await _cacheLocally(kp.privateKey);
    } catch (_) {
      // best-effort — o envio e a leitura tratam a ausência adiante
    }
  }

  /// Chave pública de [userId]. Cacheada: uma conta tem uma só e ela não muda.
  static Future<String?> _publicKeyOf(String userId) async {
    final cached = _publicCache[userId];
    if (cached != null) return cached;
    final row = await _db
        .from('user_keys')
        .select('public_key')
        .eq('user_id', userId)
        .maybeSingle();
    final pub = row?['public_key'] as String?;
    if (pub != null) _publicCache[userId] = pub;
    return pub;
  }

  // ── Envelope (formato puro, testável) ───────────────────────

  /// Serializa o envelope: quem enviou + uma cópia cifrada por PESSOA.
  ///
  /// Antes era uma cópia por aparelho (v2), e cada aparelho morto que ficava
  /// cadastrado inflava toda mensagem. Com a chave por conta são sempre duas.
  @visibleForTesting
  static String buildEnvelope(
          String senderUserId, Map<String, String> envelopes) =>
      jsonEncode({'v': 3, 's': senderUserId, 'e': envelopes});

  /// Lê o envelope e devolve quem enviou e a cópia destinada a [myUserId].
  ///
  /// Retorna `null` para qualquer coisa que não seja um envelope v3 válido —
  /// inclusive os formatos antigos, que ninguém consegue mais abrir.
  @visibleForTesting
  static ({String senderUserId, String? cipher})? parseEnvelope(
      String packed, String myUserId) {
    try {
      final decoded = jsonDecode(packed);
      if (decoded is! Map || decoded['v'] != 3) return null;
      final s = decoded['s'];
      final e = decoded['e'];
      if (s is! String || e is! Map) return null;
      return (senderUserId: s, cipher: e[myUserId] as String?);
    } catch (_) {
      return null;
    }
  }

  // ── Cifrar e decifrar ───────────────────────────────────────

  /// Cifra [plaintext] para a conversa com [otherUserId].
  static Future<String> encryptFor(String otherUserId, String plaintext) async {
    final uid = _uid;
    final priv = await _myPrivateKey();
    if (uid == null || priv == null) {
      throw StateError('Chave da conta indisponível — tente de novo.');
    }

    final peerPub = await _publicKeyOf(otherUserId);
    if (peerPub == null) {
      throw StateError('O contato ainda não ativou o chat seguro.');
    }

    final envelopes = <String, String>{
      otherUserId: await ChatCrypto.encrypt(
        myPrivateKey: priv,
        peerPublicKey: peerPub,
        plaintext: plaintext,
      ),
    };

    // Cópia para mim: sem ela eu não leria, em outro aparelho, o que enviei.
    if (otherUserId != uid) {
      final myPub = await _publicKeyOf(uid);
      if (myPub != null) {
        envelopes[uid] = await ChatCrypto.encrypt(
          myPrivateKey: priv,
          peerPublicKey: myPub,
          plaintext: plaintext,
        );
      }
    }

    return buildEnvelope(uid, envelopes);
  }

  /// Decifra uma mensagem enviada por [senderUserId]. Nunca lança: em caso de
  /// falha devolve [lockedMarker], pra não quebrar a lista de mensagens.
  static Future<String> decryptFrom(String senderUserId, String packed) async {
    if (packed.isEmpty) return '';
    try {
      final uid = _uid;
      final priv = await _myPrivateKey();
      if (uid == null || priv == null) return lockedMarker;

      final env = parseEnvelope(packed, uid);
      final mine = env?.cipher;
      if (env == null || mine == null) return lockedMarker;

      final senderPub = await _publicKeyOf(env.senderUserId);
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

  /// Limpa o que ficou deste usuário no aparelho (logout).
  ///
  /// Apaga também a cópia local da chave privada: ela volta do servidor no
  /// próximo login, então mantê-la só serviria para o próximo usuário do mesmo
  /// aparelho encontrar a chave de quem saiu.
  static Future<void> clearCache() async {
    _privateKey = null;
    _publicCache.clear();
    try {
      await _storage.delete(key: _privKeyStorageKey);
    } catch (_) {}
  }
}
