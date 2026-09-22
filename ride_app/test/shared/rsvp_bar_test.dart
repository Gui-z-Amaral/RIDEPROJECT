import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/shared/widgets/rsvp_bar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('Rsvp', () {
    test('os valores são os que o banco aceita', () {
      // A coluna `rsvp` só entende estes três; errar aqui salva sem reclamar
      // e some da lista de presença.
      expect(Rsvp.going, 'going');
      expect(Rsvp.maybe, 'maybe');
      expect(Rsvp.declined, 'declined');
    });
  });

  group('RsvpBar', () {
    testWidgets('mostra as três opções', (tester) async {
      await tester.pumpWidget(
          _wrap(RsvpBar(myRsvp: null, onRsvp: (_) {})));
      expect(find.text('Vou'), findsOneWidget);
      expect(find.text('Talvez'), findsOneWidget);
      expect(find.text('Não'), findsOneWidget);
    });

    testWidgets('o rótulo do "não" é configurável', (tester) async {
      await tester.pumpWidget(_wrap(
          RsvpBar(myRsvp: null, onRsvp: (_) {}, declinedLabel: 'Não vou')));
      expect(find.text('Não vou'), findsOneWidget);
      expect(find.text('Não'), findsNothing);
    });

    testWidgets('cada toque devolve o valor do banco', (tester) async {
      final tocados = <String>[];
      await tester.pumpWidget(
          _wrap(RsvpBar(myRsvp: null, onRsvp: tocados.add)));

      await tester.tap(find.text('Vou'));
      await tester.tap(find.text('Talvez'));
      await tester.tap(find.text('Não'));
      expect(tocados, [Rsvp.going, Rsvp.maybe, Rsvp.declined]);
    });

    testWidgets('sem resposta, nenhuma opção fica marcada', (tester) async {
      await tester.pumpWidget(
          _wrap(RsvpBar(myRsvp: null, onRsvp: (_) {})));
      final chips = tester.widgetList<RsvpChip>(find.byType(RsvpChip));
      expect(chips.every((c) => !c.selected), isTrue);
    });

    testWidgets('marca só a opção respondida', (tester) async {
      await tester.pumpWidget(
          _wrap(RsvpBar(myRsvp: Rsvp.maybe, onRsvp: (_) {})));
      final chips = tester.widgetList<RsvpChip>(find.byType(RsvpChip)).toList();
      expect(chips.where((c) => c.selected).length, 1);
      expect(chips.firstWhere((c) => c.selected).label, 'Talvez');
    });

    testWidgets('valor desconhecido não marca nada', (tester) async {
      // Defesa contra linha antiga ou resposta malformada do servidor.
      await tester.pumpWidget(
          _wrap(RsvpBar(myRsvp: 'qualquer', onRsvp: (_) {})));
      final chips = tester.widgetList<RsvpChip>(find.byType(RsvpChip));
      expect(chips.any((c) => c.selected), isFalse);
    });
  });
}
