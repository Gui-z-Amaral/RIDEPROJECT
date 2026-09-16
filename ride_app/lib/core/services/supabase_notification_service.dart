import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../utils/db_time.dart';

/// Resultado do agrupamento das notificações de mensagem.
class CollapsedNotifications {
  /// O que a UI deve mostrar (uma linha por conversa, com contador).
  final List<NotificationModel> visible;

  /// IDs das linhas redundantes, que podem ser apagadas do banco.
  final List<String> redundantIds;

  const CollapsedNotifications(this.visible, this.redundantIds);
}

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

  /// Notificações já **agrupadas**: várias mensagens do mesmo contato viram uma
  /// linha só com contador, e as linhas redundantes são apagadas do banco.
  ///
  /// O agrupamento acontece aqui (no destinatário) e não no envio porque a RLS
  /// só deixa cada usuário ler/alterar as PRÓPRIAS notificações — quem envia
  /// nem enxerga a notificação anterior para somar.
  static Future<List<NotificationModel>> getNotificationsGrouped() async {
    final all = await getNotifications();
    final result = collapseMessages(all);

    if (result.redundantIds.isNotEmpty) {
      // Best-effort: se a limpeza falhar, a UI já está correta de qualquer forma.
      try {
        await _db
            .from('notifications')
            .delete()
            .inFilter('id', result.redundantIds)
            .eq('user_id', _uid);
      } catch (_) {}
    }
    return result.visible;
  }

  /// Apaga as notificações de mensagem vindas de [fromUserId].
  ///
  /// Usado quando o usuário está com a conversa dessa pessoa **aberta**: não
  /// faz sentido acumular aviso de algo que ele está lendo agora.
  static Future<void> clearMessageNotificationsFrom(String fromUserId) async {
    try {
      await _db
          .from('notifications')
          .delete()
          .eq('user_id', _uid)
          .eq('type', 'message')
          .filter('data->>fromUserId', 'eq', fromUserId);
    } catch (_) {}
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

  // ── Limpar todo o histórico de notificações ────────────────
  static Future<void> clearAll() async {
    await _db.from('notifications').delete().eq('user_id', _uid);
  }

  // ── Apagar uma notificação específica ──────────────────────
  static Future<void> delete(String id) async {
    await _db.from('notifications').delete().eq('id', id).eq('user_id', _uid);
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

  // ── Push: registro de token FCM do aparelho ────────────────
  /// Salva (ou move) o token FCM do aparelho para o usuário logado.
  /// onConflict no token: se o mesmo aparelho logar com outra conta, o token
  /// passa a apontar para o novo dono.
  static Future<void> saveDeviceToken(String token,
      {String platform = 'android'}) async {
    await _db.from('device_tokens').upsert({
      'token': token,
      'user_id': _uid,
      'platform': platform,
      'updated_at': DbTime.nowForDb(),
    }, onConflict: 'token');
  }

  /// Remove o token do aparelho (chamado no logout).
  static Future<void> removeDeviceToken(String token) async {
    await _db.from('device_tokens').delete().eq('token', token);
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
        createdAt: DbTime.parse(r['created_at']),
      );

  /// Agrupa notificações de mensagem por remetente: mantém a **mais recente**
  /// de cada conversa, com o total no corpo ("12 novas mensagens"), e devolve
  /// as demais como redundantes.
  ///
  /// As notificações de outros tipos passam intactas, preservando a ordem.
  /// Espera a lista já ordenada da mais nova para a mais antiga.
  @visibleForTesting
  static CollapsedNotifications collapseMessages(List<NotificationModel> all) {
    final visible = <NotificationModel>[];
    final redundant = <String>[];
    final counts = <String, int>{};
    final indexOfSender = <String, int>{};

    for (final n in all) {
      if (n.type != 'message') {
        visible.add(n);
        continue;
      }
      final from = n.data['fromUserId'] as String? ?? '';
      if (from.isEmpty) {
        visible.add(n); // sem remetente identificável: não dá para agrupar
        continue;
      }
      final known = indexOfSender[from];
      if (known == null) {
        indexOfSender[from] = visible.length;
        counts[from] = 1;
        visible.add(n);
      } else {
        counts[from] = counts[from]! + 1;
        redundant.add(n.id);
      }
    }

    // Reescreve o corpo das que agruparam mais de uma.
    indexOfSender.forEach((from, i) {
      final total = counts[from] ?? 1;
      if (total < 2) return;
      final base = visible[i];
      visible[i] = NotificationModel(
        id: base.id,
        userId: base.userId,
        type: base.type,
        title: base.title,
        body: '📩 $total novas mensagens',
        data: {...base.data, 'count': total},
        isRead: base.isRead,
        createdAt: base.createdAt,
      );
    });

    return CollapsedNotifications(visible, redundant);
  }
}
