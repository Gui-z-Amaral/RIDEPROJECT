import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/db_time.dart';

void main() {
  group('DbTime.tryParse', () {
    test('converte TIMESTAMPTZ em UTC para a hora local do aparelho', () {
      final dt = DbTime.tryParse('2026-09-17T11:00:00+00:00')!;
      expect(dt.isUtc, isFalse);
      // Mesmo instante, relógio do aparelho.
      expect(dt.toUtc(), DateTime.utc(2026, 9, 17, 11));
    });

    test('respeita o deslocamento vindo na string', () {
      // -03:00 e o mesmo instante em UTC apontam para o mesmo momento.
      final comOffset = DbTime.tryParse('2026-09-17T08:00:00-03:00')!;
      final emUtc = DbTime.tryParse('2026-09-17T11:00:00Z')!;
      expect(comOffset.isAtSameMomentAs(emUtc), isTrue);
    });

    test('aceita DateTime já pronto e devolve local', () {
      final dt = DbTime.tryParse(DateTime.utc(2026, 9, 17, 11))!;
      expect(dt.isUtc, isFalse);
      expect(dt.toUtc(), DateTime.utc(2026, 9, 17, 11));
    });

    test('null, vazio e tipo inesperado não explodem', () {
      expect(DbTime.tryParse(null), isNull);
      expect(DbTime.tryParse(''), isNull);
      expect(DbTime.tryParse(42), isNull);
    });

    test('data inválida vira null em vez de exceção', () {
      expect(DbTime.tryParse('nao é data'), isNull);
    });
  });

  group('DbTime.parse', () {
    test('usa o valor quando existe', () {
      expect(
        DbTime.parse('2026-09-17T11:00:00Z').toUtc(),
        DateTime.utc(2026, 9, 17, 11),
      );
    });

    test('cai no fallback quando o valor é nulo', () {
      final fallback = DateTime(2020, 1, 1);
      expect(DbTime.parse(null, fallback: fallback), fallback);
    });

    test('sem valor e sem fallback devolve agora (nunca nulo)', () {
      final antes = DateTime.now();
      final r = DbTime.parse(null);
      expect(r.isBefore(antes.subtract(const Duration(seconds: 5))), isFalse);
    });
  });

  group('DbTime.toDb', () {
    test('grava em UTC, com o Z explícito', () {
      // O bug original: toIso8601String() num DateTime local gera string SEM
      // fuso, e o Postgres (em UTC) lia o horário como se já fosse UTC.
      final local = DateTime(2026, 9, 17, 8);
      final s = DbTime.toDb(local)!;
      expect(s.endsWith('Z'), isTrue);
      expect(DateTime.parse(s).isAtSameMomentAs(local), isTrue);
    });

    test('ida e volta preserva o instante', () {
      final local = DateTime(2026, 9, 17, 8, 30);
      final voltou = DbTime.tryParse(DbTime.toDb(local))!;
      expect(voltou.isAtSameMomentAs(local), isTrue);
    });

    test('null continua null', () {
      expect(DbTime.toDb(null), isNull);
    });
  });

  group('DbTime.nowForDb', () {
    test('sai em UTC, pronto para comparar com uma coluna TIMESTAMPTZ', () {
      final s = DbTime.nowForDb();
      expect(s.endsWith('Z'), isTrue);
      final diff = DateTime.now().difference(DateTime.parse(s)).abs();
      expect(diff.inMinutes, lessThan(1));
    });
  });
}
