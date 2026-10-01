import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:ride_app/core/constants/text_limits.dart';
import 'package:ride_app/core/utils/db_errors.dart';
import 'package:ride_app/core/utils/extensions.dart';

void main() {
  group('DbErrors.textoInvalido (migration 045)', () {
    PostgrestException erro(String motivo, String campo) => PostgrestException(
        message: 'texto_invalido:$motivo:$campo', code: '23514');

    test('palavra bloqueada vira frase, sem repetir a palavra', () {
      final m = DbErrors.textoInvalido(erro('improprio', 'clube'))!;
      expect(m, 'O nome do motoclube tem uma palavra que não é permitida no RideApp.');
    });

    test('longo diz o limite do campo', () {
      expect(DbErrors.textoInvalido(erro('longo', 'evento')),
          'O nome do evento pode ter no máximo ${TextLimits.evento} caracteres.');
    });

    test('curto diz o mínimo do campo', () {
      expect(DbErrors.textoInvalido(erro('curto', 'nome')),
          'O nome precisa ter pelo menos 2 caracteres.');
    });

    test('vazio e formato', () {
      expect(DbErrors.textoInvalido(erro('vazio', 'viagem')),
          'O título da viagem não pode ficar em branco.');
      expect(DbErrors.textoInvalido(erro('formato', 'username')),
          'O @ só pode ter letras minúsculas, números e _.');
    });

    test('reconhece o padrão mesmo embrulhado em outro erro', () {
      // O GoTrue e o functions client embrulham a mensagem do Postgres.
      expect(
        DbErrors.textoInvalido(
            Exception('AuthException: texto_invalido:improprio:nome')),
        contains('O nome'),
      );
    });

    test('erro que não é de texto devolve null', () {
      expect(DbErrors.textoInvalido(Exception('socket closed')), isNull);
      expect(
          DbErrors.textoInvalido(
              PostgrestException(message: 'duplicate key', code: '23505')),
          isNull);
    });

    test('campo ou motivo desconhecido não vaza código na tela', () {
      final m = DbErrors.textoMensagem('outro', 'campo_novo');
      expect(m, 'O texto não foi aceito. Revise e tente de novo.');
    });
  });

  group('DbErrors.mensagem', () {
    test('regra de texto ganha do fallback', () {
      final e = PostgrestException(message: 'texto_invalido:longo:bio');
      expect(DbErrors.mensagem(e, fallback: 'x'), contains('A bio'));
    });

    test('outro erro usa o fallback, nunca o texto cru', () {
      final e = PostgrestException(
          message: 'column profiles.segredo does not exist', code: '42703');
      expect(DbErrors.mensagem(e, fallback: 'Tente de novo.'), 'Tente de novo.');
    });
  });

  group('TextLimits', () {
    test('todo campo com nome amigável tem regra', () {
      for (final campo in [
        'nome', 'username', 'bio', 'clube', 'clube_desc',
        'evento', 'evento_desc', 'viagem', 'role', 'mensagem',
      ]) {
        expect(TextLimits.regras.containsKey(campo), isTrue, reason: campo);
      }
    });

    test('mínimo nunca passa do máximo', () {
      TextLimits.regras.forEach((campo, r) {
        expect(r.$1 <= r.$2, isTrue, reason: campo);
      });
    });
  });

  group('String.paraBusca', () {
    test('vírgula e parêntese saem: quebravam o filtro do PostgREST', () {
      expect('Silva, João'.paraBusca, 'Silva João');
      expect('x),id.eq.1'.paraBusca, 'x id.eq.1');
    });

    test('curingas do ilike saem', () {
      expect('%admin*'.paraBusca, 'admin');
    });

    test('aspas, barra invertida e dois-pontos saem', () {
      expect(r'a"b\c:d'.paraBusca, 'a b c d');
    });

    test('espaços repetidos viram um só', () {
      expect('  joão    silva '.paraBusca, 'joão silva');
    });

    test('texto normal passa igual, com acento e _', () {
      expect('joão_silva'.paraBusca, 'joão_silva');
    });

    test('corta em 50 caracteres', () {
      expect(('a' * 80).paraBusca.length, 50);
    });

    test('só caractere especial vira vazio', () {
      expect(',,()%'.paraBusca, isEmpty);
    });
  });
}
