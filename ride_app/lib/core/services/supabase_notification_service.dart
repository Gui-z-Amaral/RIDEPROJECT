import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class SupabaseNotificationService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar notificações do usuário logado ──────────────────
  static Future<List<NotificationModel>> getNotifications() async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(_rowToNotification).toList();
  }

  // ── Marcar uma como lida ───────────────────────────────────
  static Future<void> markAsRead(String id) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id)
        .eq('user_id', _uid);
  }

  // ── Marcar todas como lidas ────────────────────────────────
  static Future<void> markAllAsRead() async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _uid)
        .eq('is_read', false);
  }

  // ── Enviar convite para uma lista de usuários ──────────────
  static Future<void> sendInviteNotifications({
    required List<String> userIds,
    required String type,   // 'ride_invite' | 'trip_invite'
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (userIds.isEmpty) return;
    await _db.from('notifications').insert(
      userIds
          .map((uid) => {
                'user_id': uid,
                'type': type,
                'title': title,
                'body': body,
                'data': data,
              })
          .toList(),
    );
  }

  // ── Tempo real: novas notificações chegando ────────────────
  static RealtimeChannel subscribeToNotifications(
      void Function(NotificationModel) onNew) {
    return _db
        .channel('notifications:$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _uid,
          ),
          callback: (payload) => onNew(_rowToNotification(payload.newRecord)),
        )
        .subscribe();
  }

  // ── Helper ─────────────────────────────────────────────────
  static NotificationModel _rowToNotification(Map<String, dynamic> r) =>
      NotificationModel(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        type: r['type'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        data: (r['data'] as Map<String, dynamic>?) ?? {},
        isRead: r['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}
