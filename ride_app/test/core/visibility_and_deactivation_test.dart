import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/event_model.dart';
import 'package:ride_app/core/models/user_model.dart';
import 'package:ride_app/shared/widgets/visibility_switch.dart';

void main() {
  group('EventModel.isPublic', () {
    Map<String, dynamic> base() => {
          'id': 'e1',
          'creator_id': 'u1',
          'title': 'Encontro',
          'starts_at': '2026-10-01T12:00:00Z',
        };

    test('lê a visibilidade da linha', () {
      expect(EventModel.fromMap({...base(), 'is_public': false}).isPublic,
          isFalse);
      expect(
          EventModel.fromMap({...base(), 'is_public': true}).isPublic, isTrue);
    });

    test('campo ausente cai em público', () {
      // Linhas antigas, gravadas antes da coluna existir, eram visíveis a
      // todos — o padrão preserva o que já estava valendo.
      expect(EventModel.fromMap(base()).isPublic, isTrue);
    });
  });

  group('UserModel.deactivatedAt', () {
    Map<String, dynamic> base() => {
          'id': 'u1',
          'name': 'Usuário inativo',
          'username': 'inativo_abc',
        };

    test('conta ativa não tem data de desativação', () {
      expect(UserModel.fromMap(base()).deactivatedAt, isNull);
    });

    test('conta desativada traz a data, na hora do aparelho', () {
      final u = UserModel.fromMap(
          {...base(), 'deactivated_at': '2026-09-16T12:00:00Z'});
      expect(u.deactivatedAt, isNotNull);
      expect(u.deactivatedAt!.isUtc, isFalse);
      expect(u.deactivatedAt!.toUtc(), DateTime.utc(2026, 9, 16, 12));
    });

    test('copyWith não perde a desativação', () {
      // Se perdesse, qualquer edição de perfil "reativaria" a conta na memória
      // do app e a tela voltaria a mostrar os dados como se nada tivesse
      // acontecido.
      final u = UserModel.fromMap(
          {...base(), 'deactivated_at': '2026-09-16T12:00:00Z'});
      expect(u.copyWith(bio: 'nova').deactivatedAt, u.deactivatedAt);
    });
  });

  group('VisibilitySwitch', () {
    Future<void> montar(WidgetTester tester,
        {required bool isPublic, ValueChanged<bool>? onChanged}) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VisibilitySwitch(
            isPublic: isPublic,
            onChanged: onChanged ?? (_) {},
            publicHint: 'Qualquer pessoa vê',
            privateHint: 'Só convidados',
          ),
        ),
      ));
    }

    testWidgets('mostra o estado público com a dica certa', (tester) async {
      await montar(tester, isPublic: true);
      expect(find.text('Público'), findsOneWidget);
      expect(find.text('Qualquer pessoa vê'), findsOneWidget);
      expect(find.text('Só convidados'), findsNothing);
    });

    testWidgets('mostra o estado privado com a dica certa', (tester) async {
      await montar(tester, isPublic: false);
      expect(find.text('Privado'), findsOneWidget);
      expect(find.text('Só convidados'), findsOneWidget);
    });

    testWidgets('avisa a mudança', (tester) async {
      bool? recebido;
      await montar(tester, isPublic: true, onChanged: (v) => recebido = v);
      await tester.tap(find.byType(SwitchListTile));
      expect(recebido, isFalse);
    });
  });
}
