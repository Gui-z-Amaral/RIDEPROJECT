import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../models/message_model.dart';

class FriendTripStory {
  final UserModel friend;
  final String tripId;
  final String tripTitle;
  final String destination;

  const FriendTripStory({
    required this.friend,
    required this.tripId,
    required this.tripTitle,
    required this.destination,
  });
}

class SupabaseSocialService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Friends ────────────────────────────────────────────────
  static Future<List<UserModel>> getFriends() async {
    // Separate queries — no PostgREST joins to avoid RLS hangs
    final asUser = await _db
        .from('friendships')
        .select('friend_id')
        .eq('user_id', _uid)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final asFriend = await _db
        .from('friendships')
        .select('user_id')
        .eq('friend_id', _uid)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final friendIds = <String>{};
    for (final row in asUser as List) {
      friendIds.add(row['friend_id'] as String);
    }
    for (final row in asFriend as List) {
      friendIds.add(row['user_id'] as String);
    }

    if (friendIds.isEmpty) return [];

    final profiles = await _db
        .from('profiles')
        .select()
        .inFilter('id', friendIds.toList())
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    return (profiles as List).map((p) => _rowToUser(p)).toList();
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
        .select('id, from_user_id, created_at')
        .eq('to_user_id', _uid)
        .eq('status', 'pending')
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    if ((rows as List).isEmpty) return [];

    final fromIds = rows.map((r) => r['from_user_id'] as String).toList();
    final profiles = await _db
        .from('profiles')
        .select()
        .inFilter('id', fromIds)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final profileMap = {
      for (final p in profiles as List) (p['id'] as String): _rowToUser(p),
    };

    return rows.map((r) {
      final fromId = r['from_user_id'] as String;
      return FriendRequestModel(
        id: r['id'] as String,
        from: profileMap[fromId] ?? UserModel(id: fromId, name: '', username: ''),
        to: UserModel(id: _uid, name: '', username: ''),
        status: FriendRequestStatus.pending,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  static Future<List<FriendRequestModel>> getSentRequests() async {
    final rows = await _db
        .from('friend_requests')
        .select('id, to_user_id, created_at')
        .eq('from_user_id', _uid)
        .eq('status', 'pending')
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    if ((rows as List).isEmpty) return [];

    final toIds = rows.map((r) => r['to_user_id'] as String).toList();
    final profiles = await _db
        .from('profiles')
        .select()
        .inFilter('id', toIds)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final profileMap = {
      for (final p in profiles as List) (p['id'] as String): _rowToUser(p),
    };

    return rows.map((r) {
      final toId = r['to_user_id'] as String;
      return FriendRequestModel(
        id: r['id'] as String,
        from: UserModel(id: _uid, name: '', username: ''),
        to: profileMap[toId] ?? UserModel(id: toId, name: '', username: ''),
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

  // ── Friends' recent trips (for home stories) ──────────────
  static Future<List<FriendTripStory>> getFriendsRecentTrips() async {
    final friends = await getFriends();
    if (friends.isEmpty) return [];

    final friendIds = friends.map((f) => f.id).toList();
    final friendMap = {for (final f in friends) f.id: f};

    // Trips created by friends that are upcoming
    final rows = await _db
        .from('trips')
        .select('id, title, destination_address, creator_id')
        .inFilter('creator_id', friendIds)
        .inFilter('status', ['planned', 'active'])
        .order('created_at', ascending: false)
        .limit(20)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    return (rows as List).map((r) {
      final friend = friendMap[r['creator_id'] as String];
      if (friend == null) return null;
      return FriendTripStory(
        friend: friend,
        tripId: r['id'] as String,
        tripTitle: r['title'] as String,
        destination: r['destination_address'] as String? ?? '',
      );
    }).whereType<FriendTripStory>().toList();
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

  /// ID canônico da conversa: IDs dos dois usuários em ordem alfabética.
  /// Garante que A→B e B→A usem o mesmo chat_id na tabela messages.
  static String canonicalChatId(String otherUserId) {
    final ids = [_uid, otherUserId]..sort();
    return ids.join('_');
  }

  static Future<List<MessageModel>> getMessages(String otherUserId) async {
    final chatId = canonicalChatId(otherUserId);
    final rows = await _db
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(name, avatar_url)')
        .eq('chat_id', chatId)
        .order('sent_at');

    return (rows as List).map((r) => _rowToMessage(r, chatId)).toList();
  }

  static Future<MessageModel> sendMessage(String otherUserId, String content,
      {String? imageUrl}) async {
    final chatId = canonicalChatId(otherUserId);
    final row = await _db.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _uid,
      'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
    }).select('*, sender:profiles!messages_sender_id_fkey(name, avatar_url)').single();

    // Notifica o destinatário (best-effort)
    try {
      final sender = await _db
          .from('profiles')
          .select('name')
          .eq('id', _uid)
          .maybeSingle();
      final senderName = sender?['name'] as String? ?? 'Alguém';
      await _db.from('notifications').insert({
        'user_id': otherUserId,
        'type': 'message',
        'title': senderName,
        'body': content.isNotEmpty ? content : '📷 Imagem',
        'data': {'fromUserId': _uid, 'fromName': senderName},
      });
    } catch (_) {}

    return _rowToMessage(row, chatId);
  }

  static Future<String> uploadChatImage(
      String otherUserId, Uint8List bytes, String extension) async {
    final chatId = canonicalChatId(otherUserId);
    final path =
        'chat/$chatId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _db.storage.from('chat-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extension', upsert: false),
        );
    return _db.storage.from('chat-images').getPublicUrl(path);
  }

  static MessageModel _rowToMessage(Map<String, dynamic> r, String chatId) {
    final sender = r['sender'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: r['id'] as String,
      senderId: r['sender_id'] as String,
      senderName: sender['name'] as String? ?? '',
      senderAvatar: sender['avatar_url'] as String?,
      content: r['content'] as String? ?? '',
      imageUrl: r['image_url'] as String?,
      sentAt: DateTime.parse(r['sent_at'] as String),
      isRead: r['is_read'] as bool? ?? false,
      chatId: chatId,
    );
  }

  // ── Real-time messages ─────────────────────────────────────
  static RealtimeChannel subscribeToMessages(
      String otherUserId, void Function(MessageModel) onMessage) {
    final chatId = canonicalChatId(otherUserId);
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
              content: newRow['content'] as String? ?? '',
              imageUrl: newRow['image_url'] as String?,
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
