// Testes da criptografia ponta a ponta do chat.
// Verificam o round-trip (A↔B), a simetria do ECDH e que um terceiro não lê.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/chat_crypto.dart';

void main() {
  group('ChatCrypto', () {
    test('round-trip: A cifra para B, B decifra (ECDH simétrico)', () async {
      final a = await ChatCrypto.generateKeyPair();
      final b = await ChatCrypto.generateKeyPair();

      final cipher = await ChatCrypto.encrypt(
        myPrivateKey: a.privateKey,
        peerPublicKey: b.publicKey,
        plaintext: 'e aí, bora rolê sábado?',
      );

      // B decifra com a SUA privada + a pública de A → mesma chave de conversa.
      final clear = await ChatCrypto.decrypt(
        myPrivateKey: b.privateKey,
        peerPublicKey: a.publicKey,
        packed: cipher,
      );
      expect(clear, 'e aí, bora rolê sábado?');
    });

    test('o próprio remetente relê a mensagem (mesma chave de conversa)', () async {
      final a = await ChatCrypto.generateKeyPair();
      final b = await ChatCrypto.generateKeyPair();

      final cipher = await ChatCrypto.encrypt(
        myPrivateKey: a.privateKey,
        peerPublicKey: b.publicKey,
        plaintext: 'minha própria mensagem',
      );
      // A relê usando SUA privada + pública de B (é como getMessages funciona).
      final clear = await ChatCrypto.decrypt(
        myPrivateKey: a.privateKey,
        peerPublicKey: b.publicKey,
        packed: cipher,
      );
      expect(clear, 'minha própria mensagem');
    });

    test('um terceiro NÃO consegue decifrar', () async {
      final a = await ChatCrypto.generateKeyPair();
      final b = await ChatCrypto.generateKeyPair();
      final intruso = await ChatCrypto.generateKeyPair();

      final cipher = await ChatCrypto.encrypt(
        myPrivateKey: a.privateKey,
        peerPublicKey: b.publicKey,
        plaintext: 'segredo',
      );

      // Intruso tenta com a própria privada + pública de A → chave diferente.
      expect(
        () => ChatCrypto.decrypt(
          myPrivateKey: intruso.privateKey,
          peerPublicKey: a.publicKey,
          packed: cipher,
        ),
        throwsA(anything),
      );
    });

    test('cada cifragem gera saída diferente (nonce aleatório)', () async {
      final a = await ChatCrypto.generateKeyPair();
      final b = await ChatCrypto.generateKeyPair();
      final c1 = await ChatCrypto.encrypt(
          myPrivateKey: a.privateKey, peerPublicKey: b.publicKey, plaintext: 'x');
      final c2 = await ChatCrypto.encrypt(
          myPrivateKey: a.privateKey, peerPublicKey: b.publicKey, plaintext: 'x');
      expect(c1, isNot(equals(c2)));
    });

    test('saída tem o prefixo de versão v1:', () async {
      final a = await ChatCrypto.generateKeyPair();
      final b = await ChatCrypto.generateKeyPair();
      final c = await ChatCrypto.encrypt(
          myPrivateKey: a.privateKey, peerPublicKey: b.publicKey, plaintext: 'oi');
      expect(c.startsWith('v1:'), isTrue);
    });

    test('publicFromPrivate recupera a mesma pública do par gerado', () async {
      final a = await ChatCrypto.generateKeyPair();
      final pub = await ChatCrypto.publicFromPrivate(a.privateKey);
      expect(pub, a.publicKey);
    });

    test('formato inválido lança FormatException', () async {
      final a = await ChatCrypto.generateKeyPair();
      final b = await ChatCrypto.generateKeyPair();
      expect(
        () => ChatCrypto.decrypt(
          myPrivateKey: a.privateKey,
          peerPublicKey: b.publicKey,
          packed: 'texto-sem-prefixo',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
