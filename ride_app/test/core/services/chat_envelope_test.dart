import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/chat_key_service.dart';

/// Formato do envelope do chat (v3, migration 036): uma cópia cifrada por
/// PESSOA, mais o id de quem enviou — necessário para abrir com a chave certa.
///
/// Antes era uma cópia por aparelho (v2). Mudou porque a chave deixou de ser do
/// dispositivo e passou a ser da conta: com a antiga, limpar os dados do
/// navegador tornava todo o histórico ilegível.
void main() {
  group('buildEnvelope', () {
    test('monta v3 com o remetente e as cópias', () {
      final packed = ChatKeyService.buildEnvelope(
        'user-remetente',
        {'user-a': 'cifra-a', 'user-b': 'cifra-b'},
      );
      final map = jsonDecode(packed) as Map<String, dynamic>;
      expect(map['v'], 3);
      expect(map['s'], 'user-remetente');
      expect((map['e'] as Map)['user-a'], 'cifra-a');
      expect((map['e'] as Map)['user-b'], 'cifra-b');
    });

    test('nunca inclui texto em claro nem chave privada', () {
      final packed =
          ChatKeyService.buildEnvelope('user-1', {'user-2': 'v1:abc'});
      expect(packed.contains('privateKey'), isFalse);
      expect(packed.contains('plaintext'), isFalse);
    });
  });

  group('parseEnvelope', () {
    test('devolve o remetente e a cópia desta pessoa', () {
      final packed = ChatKeyService.buildEnvelope(
          'user-remetente', {'eu': 'minha-cifra', 'outro': 'x'});
      final env = ChatKeyService.parseEnvelope(packed, 'eu');
      expect(env, isNotNull);
      expect(env!.senderUserId, 'user-remetente');
      expect(env.cipher, 'minha-cifra');
    });

    test('cipher nulo quando não há cópia para esta pessoa', () {
      final packed =
          ChatKeyService.buildEnvelope('user-remetente', {'outro': 'x'});
      final env = ChatKeyService.parseEnvelope(packed, 'eu');
      expect(env, isNotNull);
      expect(env!.cipher, isNull);
    });

    test('recusa o formato antigo por aparelho (v2)', () {
      // Aquelas mensagens foram apagadas na 036 justamente porque ninguém
      // consegue mais abri-las: as chaves privadas dos aparelhos se perderam.
      final v2 = jsonEncode({
        'v': 2,
        'sd': 'dev-remetente',
        'e': {'meu-dev': 'cifra'}
      });
      expect(ChatKeyService.parseEnvelope(v2, 'eu'), isNull);
    });

    test('recusa lixo e texto solto sem estourar', () {
      expect(ChatKeyService.parseEnvelope('não é json', 'eu'), isNull);
      expect(ChatKeyService.parseEnvelope('{}', 'eu'), isNull);
      expect(ChatKeyService.parseEnvelope('[]', 'eu'), isNull);
      expect(
        ChatKeyService.parseEnvelope(jsonEncode({'v': 3, 's': 1, 'e': {}}), 'eu'),
        isNull,
      );
    });
  });
}
