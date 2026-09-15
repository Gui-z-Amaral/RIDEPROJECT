import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/shared/widgets/responsive_shell.dart';

/// O app é feito para celular; em janelas largas ele vira uma coluna central.
/// A coluna é **proporcional** — acompanha o redimensionamento da janela em vez
/// de ficar travada num número fixo — com um teto para não virar uma linha de
/// texto quilométrica em monitor ultrawide.
void main() {
  /// Renderiza a shell numa janela de [width] e devolve a largura que o filho
  /// realmente recebeu.
  Future<double> childWidthAt(WidgetTester tester, double width) async {
    const childKey = Key('conteudo');
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: ResponsiveShell(
        child: SizedBox.expand(
            child: ColoredBox(color: Color(0xFF000000), key: childKey)),
      ),
    ));
    return tester.getSize(find.byKey(childKey)).width;
  }

  group('columnWidth (regra pura)', () {
    test('é proporcional à janela', () {
      expect(ResponsiveShell.columnWidth(1000),
          closeTo(1000 * ResponsiveShell.widthFactor, 0.01));
    });

    test('acompanha o redimensionamento — janela maior, coluna maior', () {
      expect(ResponsiveShell.columnWidth(1200),
          greaterThan(ResponsiveShell.columnWidth(900)));
    });

    test('nunca ultrapassa a janela', () {
      for (final w in [760.0, 1000.0, 1440.0, 1920.0, 2560.0]) {
        expect(ResponsiveShell.columnWidth(w), lessThanOrEqualTo(w));
      }
    });

    test('respeita o teto em telas ultrawide', () {
      expect(ResponsiveShell.columnWidth(3440),
          ResponsiveShell.maxContentWidth);
    });
  });

  group('renderização', () {
    testWidgets('janela estreita: o conteúdo ocupa a largura toda', (t) async {
      expect(await childWidthAt(t, 400), 400);
    });

    testWidgets('no limite do breakpoint ainda ocupa tudo', (t) async {
      expect(await childWidthAt(t, ResponsiveShell.breakpoint),
          ResponsiveShell.breakpoint);
    });

    testWidgets('janela larga: usa a coluna proporcional', (t) async {
      expect(await childWidthAt(t, 1400),
          closeTo(ResponsiveShell.columnWidth(1400), 0.01));
    });

    testWidgets('redimensionar a janela redimensiona a coluna', (t) async {
      final estreita = await childWidthAt(t, 1000);
      final larga = await childWidthAt(t, 1300);
      expect(larga, greaterThan(estreita));
    });

    testWidgets('nunca estoura o layout em nenhuma largura', (t) async {
      for (final w in [760.0, 900.0, 1100.0, 1920.0]) {
        expect(await childWidthAt(t, w), lessThanOrEqualTo(w));
      }
    });
  });
}
