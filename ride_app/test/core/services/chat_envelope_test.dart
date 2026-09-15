import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/chat_key_service.dart';

/// Formato do envelope do chat multi-dispositivo: uma cópia cifrada por
/// aparelho, mais a identificação do dispositivo que enviou (necessária para
/// abrir a cópia com a chave certa).
void main() {
  group('buildEnvelope', () {
    test('monta v2 com o dispositivo remetente e as cópias', () {
      final packed = ChatKeyService.buildEnvelope(
        'dev-remetente',
        {'dev-a': 'cifra-a', 'dev-b': 'cifra-b'},
      );
      final map = jsonDecode(packed) as Map<String, dynamic>;
      expect(map['v'], 2);
      expect(map['sd'], 'dev-remetente');
      expect((map['e'] as Map)['dev-a'], 'cifra-a');
      expect((map['e'] as Map)['dev-b'], 'cifra-b');
    });

    test('nunca inclui texto em claro nem chave privada', () {
      final packed =
          ChatKeyService.buildEnvelope('dev-1', {'dev-2': 'v1:abc'});
      expect(packed.contains('privateKey'), isFalse);
      expect(packed.contains('plaintext'), isFalse);
    });
  });

  group('parseEnvelope', () {
    test('devolve o remetente e a cópia deste aparelho', () {
      final packed = ChatKeyService.buildEnvelope(
          'dev-remetente', {'meu-dev': 'minha-cifra', 'outro': 'x'});
      final env = ChatKeyService.parseEnvelope(packed, 'meu-dev');
      expect(env, isNotNull);
      expect(env!.senderDevice, 'dev-remetente');
      expect(env.cipher, 'minha-cifra');
    });

    test('cipher nulo quando não há cópia para este aparelho', () {
      // Caso real: dispositivo cadastrado DEPOIS do envio.
      final packed =
          ChatKeyService.buildEnvelope('dev-remetente', {'outro': 'x'});
      final env = ChatKeyService.parseEnvelope(packed, 'aparelho-novo');
      expect(env, isNotNull);
      expect(env!.cipher, isNull);
    });

    test('null para o formato antigo (pré multi-dispositivo)', () {
      // Mensagens da versão anterior eram só o ciphertext cru.
      expect(ChatKeyService.parseEnvelope('v1:abcdef', 'meu-dev'), isNull);
    });

    test('null para JSON sem ser envelope v2', () {
      expect(ChatKeyService.parseEnvelope('{"v":1,"x":2}', 'd'), isNull);
      expect(ChatKeyService.parseEnvelope('{"v":2,"sd":5}', 'd'), isNull);
      expect(ChatKeyService.parseEnvelope('[]', 'd'), isNull);
    });

    test('null para lixo/texto vazio, sem lançar', () {
      expect(ChatKeyService.parseEnvelope('', 'd'), isNull);
      expect(ChatKeyService.parseEnvelope('não é json', 'd'), isNull);
    });

    test('ida e volta preserva as cópias', () {
      final copias = {'a': 'v1:1', 'b': 'v1:2', 'c': 'v1:3'};
      final packed = ChatKeyService.buildEnvelope('s', copias);
      for (final e in copias.entries) {
        expect(ChatKeyService.parseEnvelope(packed, e.key)!.cipher, e.value);
      }
    });
  });
}
