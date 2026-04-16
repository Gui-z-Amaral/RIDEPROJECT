import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../models/message_model.dart';

class SupabaseSocialService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Friends ────────────────────────────────────────────────
  static Future<List<UserModel>> getFriends() async {
    // friendships has user_id + friend_id (bidirectional)
    final asUser = await _db
        .from('friendships')
        .select('friend_id, profiles!friendships_friend_id_fkey(*)')
        .eq('user_id', _uid)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final asFriend = await _db
        .from('friendships')
        .select('user_id, profiles!friendships_user_id_fkey(*)')
        .eq('friend_id', _uid)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final friends = <UserModel>[];
    for (final row in asUser as List) {
      final p = row['profiles'] as Map<String, dynamic>?;
      if (p != null) friends.add(_rowToUser(p));
    }
    for (final row in asFriend as List) {
      final p = row['profiles'] as Map<String, dynamic>?;
      if (p != null) friends.add(_rowToUser(p));
    }
    return friends;
  }

  static Future<void> sendFriendRequest(String toUserId) async {
    // Upsert: ignora caso já exista pedido pendente para evitar duplicate-key error
    await _db.from('friend_requests').upsert({
      'from_user_id': _uid,
      'to_user_id': toUserId,
      'status': 'pending',
    }, onConflict: 'from_user_id,to_user_id');

    // Busca o ID do pedido que acabou de ser criado/atualizado
    final row = await _db
        .from('friend_requests')
        .select('id')
        .eq('from_user_id', _uid)
        .eq('to_user_id', toUserId)
        .maybeSingle();
    final requestId = row?['id'] as String?;

    // Busca o nome de quem enviou
    final sender = await _db
        .from('profiles')
        .select('name')
        .eq('id', _uid)
        .maybeSingle();
    final senderName = sender?['name'] as String? ?? 'Alguém';

    // Cria notificação para o destinatário (best-effort)
    if (requestId != null) {
      try {
        await _db.from('notifications').insert({
          'user_id': toUserId,
          'type': 'friend_request',
          'title': 'Novo pedido de amizade',
          'body': '$senderName quer se conectar com você',
          'data': {
            'requestId': requestId,
            'fromUserId': _uid,
            'fromName': senderName,
          },
        });
      } catch (_) {}
    }
  }

  static Future<List<FriendRequestModel>> getReceivedRequests() async {
    final rows = await _db
        .from('friend_requests')
        .select('*, from_profile:profiles!friend_requests_from_user_id_fkey(*)')
        .eq('to_user_id', _uid)
        .eq('status', 'pending');

    return (rows as List).map((r) {
      final fromProfile = r['from_profile'] as Map<String, dynamic>;
      return FriendRequestModel(
        id: r['id'] as String,
        from: _rowToUser(fromProfile),
        to: UserModel(id: _uid, name: '', username: ''),
        status: FriendRequestStatus.pending,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  static Future<List<FriendRequestModel>> getSentRequests() async {
    final rows = await _db
        .from('friend_requests')
        .select('*, to_profile:profiles!friend_requests_to_user_id_fkey(*)')
        .eq('from_user_id', _uid)
        .eq('status', 'pending');

    return (rows as List).map((r) {
      final toProfile = r['to_profile'] as Map<String, dynamic>;
      return FriendRequestModel(
        id: r['id'] as String,
        from: UserModel(id: _uid, name: '', username: ''),
        to: _rowToUser(toProfile),
        status: FriendRequestStatus.pending,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    // Get the request to know who sent it
    final req = await _db
        .from('friend_requests')
        .select()
        .eq('id', requestId)
        .single();

    final fromUserId = req['from_user_id'] as String;

    // Update status
    await _db
        .from('friend_requests')
        .update({'status': 'accepted'})
        .eq('id', requestId);

    // Create bidirectional friendship
    await _db.from('friendships').upsert([
      {'user_id': fromUserId, 'friend_id': _uid},
      {'user_id': _uid, 'friend_id': fromUserId},
    ]);
  }

  static Future<void> rejectFriendRequest(String requestId) async {
    await _db
        .from('friend_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  // ── Search users ───────────────────────────────────────────
  static Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final rows = await _db
        .from('profiles')
        .select()
        .or('name.ilike.%$query%,username.ilike.%$query%')
        .neq('id', _uid)
        .limit(20);
    return (rows as List).map((r) => _rowToUser(r)).toList();
  }

  // ── Messages ───────────────────────────────────────────────
  static Future<List<MessageModel>> getMessages(String chatId) async {
    final rows = await _db
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(name, avatar_url)')
        .eq('chat_id', chatId)
        .order('sent_at');

    return (rows as List).map((r) {
      final sender = r['sender'] as Map<String, dynamic>? ?? {};
      return MessageModel(
        id: r['id'] as String,
        senderId: r['sender_id'] as String,
        senderName: sender['name'] as String? ?? '',
        senderAvatar: sender['avatar_url'] as String?,
        content: r['content'] as String,
        sentAt: DateTime.parse(r['sent_at'] as String),
        isRead: r['is_read'] as bool? ?? false,
        chatId: chatId,
      );
    }).toList();
  }

  static Future<MessageModel> sendMessage(String chatId, String content) async {
    final row = await _db.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _uid,
      'content': content,
    }).select('*, sender:profiles!messages_sender_id_fkey(name, avatar_url)').single();

    final sender = row['sender'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: row['id'] as String,
      senderId: _uid,
      senderName: sender['name'] as String? ?? '',
      senderAvatar: sender['avatar_url'] as String?,
      content: content,
      sentAt: DateTime.parse(row['sent_at'] as String),
      chatId: chatId,
    );
  }

  // ── Real-time messages ─────────────────────────────────────
  static RealtimeChannel subscribeToMessages(
      String chatId, void Function(MessageModel) onMessage) {
    return _db
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'chat_id',
              value: chatId),
          callback: (payload) async {
            final newRow = payload.newRecord;
            // Fetch sender name
            final profile = await _db
                .from('profiles')
                .select('name, avatar_url')
                .eq('id', newRow['sender_id'])
                .maybeSingle();
            onMessage(MessageModel(
              id: newRow['id'] as String,
              senderId: newRow['sender_id'] as String,
              senderName: profile?['name'] as String? ?? '',
              senderAvatar: profile?['avatar_url'] as String?,
              content: newRow['content'] as String,
              sentAt: DateTime.parse(newRow['sent_at'] as String),
              chatId: chatId,
            ));
          },
        )
        .subscribe();
  }

  // ── Helpers ────────────────────────────────────────────────
  static UserModel _rowToUser(Map<String, dynamic> r) => UserModel(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        username: r['username'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String?,
        bio: r['bio'] as String?,
        city: r['city'] as String?,
        motoModel: r['moto_model'] as String?,
        motoYear: r['moto_year'] as String?,
        friendsCount: (r['friends_count'] as num?)?.toInt() ?? 0,
        tripsCount: (r['trips_count'] as num?)?.toInt() ?? 0,
        isOnline: r['is_online'] as bool? ?? false,
      );
}
