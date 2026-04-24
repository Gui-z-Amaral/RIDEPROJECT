// Testes dos helpers puros de SupabaseSocialService.
//
// canonicalChatId é o método que garante que uma conversa entre A e B
// tenha o mesmo ID independente de quem abriu a tela primeiro. Se
// quebrar, mensagens trocadas antes viram "duas conversas" diferentes
// no cliente.
//
// IMPORTANTE: canonicalChatId usa _uid interno do Supabase, que requer
// o auth estar inicializado. Por isso testamos a propriedade matemática
// (comutatividade da ordenação canônica) via a lógica, não diretamente
// pelo método estático — que depende de runtime.
//
// Se no futuro canonicalChatId for refatorado para receber ambos os IDs
// como parâmetro (mais testável), dá pra testar direto sem workaround.
import 'package:flutter_test/flutter_test.dart';

/// Replica a lógica de canonicalChatId — mantenha em sync com a produção.
/// Propriedades esperadas: idempotente, comutativa, determinística.
String canonicalChatIdOf(String a, String b) {
  final ids = [a, b]..sort();
  return ids.join('_');
}

void main() {
  group('canonicalChatId (lógica)', () {
    test('é comutativo: A→B e B→A geram o mesmo id', () {
      expect(
        canonicalChatIdOf('alice', 'bob'),
        canonicalChatIdOf('bob', 'alice'),
      );
    });

    test('usa ordem alfabética crescente como canonical', () {
      expect(canonicalChatIdOf('bob', 'alice'), 'alice_bob');
      expect(canonicalChatIdOf('u-002', 'u-001'), 'u-001_u-002');
    });

    test('é determinístico — mesma entrada sempre gera a mesma saída', () {
      final first = canonicalChatIdOf('u-1', 'u-2');
      final second = canonicalChatIdOf('u-1', 'u-2');
      expect(first, second);
    });

    test('funciona com UUIDs do Supabase', () {
      const a = '6f9c0f2e-1234-4abc-9def-000000000001';
      const b = '6f9c0f2e-1234-4abc-9def-000000000002';
      final id1 = canonicalChatIdOf(a, b);
      final id2 = canonicalChatIdOf(b, a);
      expect(id1, id2);
      expect(id1.startsWith(a), isTrue); // a < b lex, então vem primeiro
    });
  });
}
