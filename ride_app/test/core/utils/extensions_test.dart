// Testes unitários das extensions utilitárias do projeto.
//
// Essas extensions são puras (sem I/O, sem dependências de plataforma),
// então rodam em milissegundos e são ideais para detectar regressões
// em formatação de datas, nomes e números exibidos na UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ride_app/core/utils/extensions.dart';

void main() {
  // Inicializa locale pt_BR para os formatters (relativeLabel/formattedShort).
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('DateTimeExt', () {
    test('formattedDate formata como dd/MM/yyyy', () {
      expect(DateTime(2025, 1, 9).formattedDate, '09/01/2025');
      expect(DateTime(2024, 12, 31).formattedDate, '31/12/2024');
    });

    test('formattedDateTime inclui hora no formato dd/MM/yyyy HH:mm', () {
      expect(
        DateTime(2025, 1, 9, 14, 5).formattedDateTime,
        '09/01/2025 14:05',
      );
    });

    test('formattedTime formata hora como HH:mm zero-padded', () {
      expect(DateTime(2025, 1, 1, 7, 3).formattedTime, '07:03');
      expect(DateTime(2025, 1, 1, 23, 59).formattedTime, '23:59');
      expect(DateTime(2025, 1, 1, 0, 0).formattedTime, '00:00');
    });

    test('formattedShort usa mês abreviado em pt_BR', () {
      // intl em pt_BR retorna o mês abreviado com ponto final ("jan.", "dez.").
      // Testamos dia + prefixo do mês para não depender dessa pontuação.
      expect(DateTime(2025, 1, 9).formattedShort.toLowerCase(),
          startsWith('09 jan'));
      expect(DateTime(2025, 12, 31).formattedShort.toLowerCase(),
          startsWith('31 dez'));
    });

    test('isToday retorna true apenas para a data do dia atual', () {
      final now = DateTime.now();
      expect(DateTime(now.year, now.month, now.day, 10, 30).isToday, isTrue);
      expect(now.subtract(const Duration(days: 1)).isToday, isFalse);
      expect(now.add(const Duration(days: 1)).isToday, isFalse);
    });

    test('isTomorrow retorna true apenas para o dia seguinte', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final sameDayAsTomorrow =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
      expect(sameDayAsTomorrow.isTomorrow, isTrue);
      expect(DateTime.now().isTomorrow, isFalse);
      expect(
        DateTime.now().add(const Duration(days: 2)).isTomorrow,
        isFalse,
      );
    });

    test('relativeLabel: hoje → "Hoje", amanhã → "Amanhã", outros → data curta',
        () {
      final now = DateTime.now();
      expect(now.relativeLabel, 'Hoje');
      expect(now.add(const Duration(days: 1)).relativeLabel, 'Amanhã');
      // Mais de 1 dia no futuro cai no formato curto (dd MMM).
      final later = DateTime(2025, 7, 15);
      expect(later.relativeLabel.toLowerCase(), startsWith('15 jul'));
    });
  });

  group('StringExt', () {
    test('capitalize: string vazia retorna string vazia', () {
      expect(''.capitalize, '');
    });

    test('capitalize: primeira letra em maiúscula, resto preservado', () {
      expect('flutter'.capitalize, 'Flutter');
      expect('hello world'.capitalize, 'Hello world');
    });

    test('capitalize: string já capitalizada permanece igual', () {
      expect('Flutter'.capitalize, 'Flutter');
    });

    test('initials: duas ou mais palavras → primeira + última em maiúscula',
        () {
      expect('João Silva'.initials, 'JS');
      expect('Maria da Silva'.initials, 'MS');
      expect('Ana Paula Costa'.initials, 'AC');
    });

    test('initials: uma palavra curta → primeiras 2 letras em maiúscula', () {
      expect('Ana'.initials, 'AN');
    });

    test('initials: uma palavra de 1 letra retorna a letra em maiúscula', () {
      expect('a'.initials, 'A');
    });

    test('initials: espaços extras não quebram', () {
      expect('  João   Silva  '.initials, 'JS');
    });
  });

  group('DoubleExt', () {
    test('formattedKm formata com 1 casa decimal e sufixo km', () {
      expect(12.345.formattedKm, '12.3 km');
      expect(0.5.formattedKm, '0.5 km');
      expect(100.0.formattedKm, '100.0 km');
    });
  });

  group('ContextExt', () {
    // ContextExt depende de um BuildContext; testamos que os getters
    // não explodem e retornam os tipos esperados ao usar um widget mínimo.
    testWidgets('expõe theme/colors/screenSize a partir do BuildContext',
        (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(capturedContext.theme, isA<ThemeData>());
      expect(capturedContext.colors, isA<ColorScheme>());
      expect(capturedContext.screenSize, isA<Size>());
      expect(capturedContext.screenWidth, greaterThan(0));
      expect(capturedContext.screenHeight, greaterThan(0));
    });
  });
}
