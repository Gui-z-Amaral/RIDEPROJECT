import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Criptografia ponta a ponta do chat (funções puras, sem I/O).
///
/// Esquema: X25519 (ECDH) para derivar um segredo compartilhado entre os dois
/// usuários → HKDF-SHA256 para virar uma chave AES-256 → AES-GCM para cifrar.
/// Como o ECDH é simétrico (X25519(a_priv, b_pub) == X25519(b_priv, a_pub)),
/// os dois lados chegam à MESMA chave da conversa, independente de quem enviou.
///
/// As chaves são strings base64 (privada = seed de 32 bytes; pública = 32 bytes).
/// Só isto é testável isoladamente; o armazenamento (secure storage) e o
/// Supabase ficam no [ChatKeyService].
class ChatCrypto {
  static final X25519 _x25519 = X25519();
  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf =
      Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // Salt/info fixos → a derivação é determinística nos dois aparelhos.
  static final List<int> _salt = utf8.encode('rideapp-chat-salt-v1');
  static final List<int> _info = utf8.encode('rideapp-chat-v1');

  static const String _prefix = 'v1:';
  static const int _nonceLen = 12; // AES-GCM
  static const int _macLen = 16;

  /// Gera um par de chaves X25519. Retorna base64 de (privada, pública).
  static Future<({String privateKey, String publicKey})> generateKeyPair() async {
    final kp = await _x25519.newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    return (
      privateKey: base64Encode(priv),
      publicKey: base64Encode(pub.bytes),
    );
  }

  /// Recalcula a chave pública a partir da privada (para republicar no servidor).
  static Future<String> publicFromPrivate(String privateKeyB64) async {
    final kp = await _x25519.newKeyPairFromSeed(base64Decode(privateKeyB64));
    final pub = await kp.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// Cifra [plaintext] para a conversa entre mim ([myPrivateKey]) e o outro
  /// usuário ([peerPublicKey]). Saída: "v1:base64(nonce|cipher|mac)".
  static Future<String> encrypt({
    required String myPrivateKey,
    required String peerPublicKey,
    required String plaintext,
  }) async {
    final key = await _deriveKey(myPrivateKey, peerPublicKey);
    final box = await _aes.encrypt(utf8.encode(plaintext), secretKey: key);
    final packed = <int>[...box.nonce, ...box.cipherText, ...box.mac.bytes];
    return '$_prefix${base64Encode(packed)}';
  }

  /// Decifra o que veio de [encrypt] usando a mesma chave de conversa.
  /// Lança [FormatException] se o formato/chave não baterem.
  static Future<String> decrypt({
    required String myPrivateKey,
    required String peerPublicKey,
    required String packed,
  }) async {
    if (!packed.startsWith(_prefix)) {
      throw const FormatException('formato de mensagem desconhecido');
    }
    final bytes = base64Decode(packed.substring(_prefix.length));
    if (bytes.length < _nonceLen + _macLen) {
      throw const FormatException('mensagem cifrada inválida');
    }
    final nonce = bytes.sublist(0, _nonceLen);
    final mac = bytes.sublist(bytes.length - _macLen);
    final cipher = bytes.sublist(_nonceLen, bytes.length - _macLen);

    final key = await _deriveKey(myPrivateKey, peerPublicKey);
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  // Deriva a chave AES da conversa (ECDH + HKDF).
  static Future<SecretKey> _deriveKey(
      String myPrivateKeyB64, String peerPublicKeyB64) async {
    final myKp = await _x25519.newKeyPairFromSeed(base64Decode(myPrivateKeyB64));
    final peerPub = SimplePublicKey(
      base64Decode(peerPublicKeyB64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: myKp,
      remotePublicKey: peerPub,
    );
    return _hkdf.deriveKey(secretKey: shared, nonce: _salt, info: _info);
  }
}
