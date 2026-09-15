import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/notification_model.dart';
import 'package:ride_app/core/services/supabase_notification_service.dart';

/// Várias mensagens do mesmo contato viravam uma notificação cada, enchendo a
/// lista. Aqui elas viram uma linha com contador, e as demais são devolvidas
/// como redundantes para serem apagadas.
NotificationModel _n(
  String id, {
  String type = 'message',
  String? from,
  String title = 'Alguém',
}) =>
    NotificationModel(
      id: id,
      userId: 'eu',
      type: type,
      title: title,
      body: '📩 Nova mensagem',
      data: from == null ? {} : {'fromUserId': from},
      isRead: false,
      createdAt: DateTime(2026, 9, 15),
    );

void main() {
  group('collapseMessages', () {
    test('mensagens do mesmo remetente viram uma linha com contador', () {
      final r = SupabaseNotificationService.collapseMessages([
        _n('1', from: 'mateus'),
        _n('2', from: 'mateus'),
        _n('3', from: 'mateus'),
      ]);
      expect(r.visible.length, 1);
      expect(r.visible.single.body, contains('3'));
      expect(r.visible.single.data['count'], 3);
      // As duas antigas podem sair do banco.
      expect(r.redundantIds, ['2', '3']);
    });

    test('mantém a mais recente (a primeira da lista)', () {
      final r = SupabaseNotificationService.collapseMessages([
        _n('nova', from: 'mateus'),
        _n('velha', from: 'mateus'),
      ]);
      expect(r.visible.single.id, 'nova');
    });

    test('remetentes diferentes não se misturam', () {
      final r = SupabaseNotificationService.collapseMessages([
        _n('1', from: 'mateus'),
        _n('2', from: 'joao'),
        _n('3', from: 'mateus'),
      ]);
      expect(r.visible.length, 2);
      expect(r.visible.map((n) => n.id), ['1', '2']);
      expect(r.redundantIds, ['3']);
    });

    test('uma única mensagem não ganha contador', () {
      final r = SupabaseNotificationService.collapseMessages([
        _n('1', from: 'mateus'),
      ]);
      expect(r.visible.single.body, '📩 Nova mensagem');
      expect(r.visible.single.data.containsKey('count'), isFalse);
      expect(r.redundantIds, isEmpty);
    });

    test('outros tipos passam intactos e na ordem', () {
      final r = SupabaseNotificationService.collapseMessages([
        _n('a', type: 'trip_invite', from: 'x'),
        _n('b', from: 'mateus'),
        _n('c', type: 'ride_invite', from: 'y'),
        _n('d', from: 'mateus'),
      ]);
      expect(r.visible.map((n) => n.id), ['a', 'b', 'c']);
      expect(r.redundantIds, ['d']);
    });

    test('mensagem sem remetente identificável não é agrupada', () {
      final r = SupabaseNotificationService.collapseMessages([
        _n('1'),
        _n('2'),
      ]);
      expect(r.visible.length, 2);
      expect(r.redundantIds, isEmpty);
    });

    test('lista vazia não quebra', () {
      final r = SupabaseNotificationService.collapseMessages([]);
      expect(r.visible, isEmpty);
      expect(r.redundantIds, isEmpty);
    });
  });
}
