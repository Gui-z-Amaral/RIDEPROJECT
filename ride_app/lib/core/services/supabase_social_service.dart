import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../models/message_model.dart';
import '../utils/image_utils.dart';
import '../utils/storage_utils.dart';
import 'chat_key_service.dart';
import '../utils/db_time.dart';

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

  // Cache em memória dos amigos do próprio usuário.
  // Reutilizado para calcular amigos em comum sem refazer 2 queries a cada
  // abertura de perfil. Invalidado em friend request accept/leave e no logout.
  static Set<String>? _myFriendIdsCache;
  static String? _cacheOwnerUid;

  static void _invalidateMyFriendsCache() {
    _myFriendIdsCache = null;
    _cacheOwnerUid = null;
  }

  /// Chamado no logout (viewmodel.reset) para evitar vazamento entre usuários.
  static void clearCaches() {
    _invalidateMyFriendsCache();
  }

  /// Busca (com caching) o conjunto de IDs de amigos de um usuário.
  /// Para o próprio usuário, guarda em memória — o cache é invalidado
  /// por operações que mudam friendships (accept/leave) e pelo logout.
  static Future<Set<String>> _fetchFriendIds(String uid) async {
    if (uid == _uid &&
        _myFriendIdsCache != null &&
        _cacheOwnerUid == _uid) {
      return _myFriendIdsCache!;
    }

    final results = await Future.wait([
      _db
          .from('friendships')
          .select('friend_id')
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 10), onTimeout: () => []),
      _db
          .from('friendships')
          .select('user_id')
          .eq('friend_id', uid)
          .timeout(const Duration(seconds: 10), onTimeout: () => []),
    ]);

    final ids = <String>{};
    for (final row in results[0] as List) {
      ids.add(row['friend_id'] as String);
    }
    for (final row in results[1] as List) {
      ids.add(row['user_id'] as String);
    }

    if (uid == _uid) {
      _myFriendIdsCache = ids;
      _cacheOwnerUid = _uid;
    }
    return ids;
  }

  // ── Friends ────────────────────────────────────────────────
  static Future<List<UserModel>> getFriends() async {
    final friendIds = await _fetchFriendIds(_uid);
    if (friendIds.isEmpty) return [];

    final profiles = await _db
        .from('profiles')
        .select(UserModel.dbColumns)
        .inFilter('id', friendIds.toList())
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    return (profiles as List).map((p) => UserModel.fromMap(p)).toList();
  }

  /// Retorna os amigos que eu tenho em comum com [otherUserId].
  /// Usa cache dos meus próprios amigos (reaproveitado entre aberturas de perfil).
  static Future<List<UserModel>> getMutualFriends(String otherUserId) async {
    if (otherUserId == _uid) return [];

    final results = await Future.wait([
      _fetchFriendIds(_uid),
      _fetchFriendIds(otherUserId),
    ]);
    final mutualIds = results[0].intersection(results[1]).toList();
    if (mutualIds.isEmpty) return [];

    final profiles = await _db
        .from('profiles')
        .select(UserModel.dbColumns)
        .inFilter('id', mutualIds)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);
    return (profiles as List).map((p) => UserModel.fromMap(p)).toList();
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
        .select(UserModel.dbColumns)
        .inFilter('id', fromIds)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final profileMap = {
      for (final p in profiles as List) (p['id'] as String): UserModel.fromMap(p),
    };

    return rows.map((r) {
      final fromId = r['from_user_id'] as String;
      return FriendRequestModel(
        id: r['id'] as String,
        from: profileMap[fromId] ?? UserModel(id: fromId, name: '', username: ''),
        to: UserModel(id: _uid, name: '', username: ''),
        status: FriendRequestStatus.pending,
        createdAt: DbTime.parse(r['created_at']),
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
        .select(UserModel.dbColumns)
        .inFilter('id', toIds)
        .timeout(const Duration(seconds: 10), onTimeout: () => []);

    final profileMap = {
      for (final p in profiles as List) (p['id'] as String): UserModel.fromMap(p),
    };

    return rows.map((r) {
      final toId = r['to_user_id'] as String;
      return FriendRequestModel(
        id: r['id'] as String,
        from: UserModel(id: _uid, name: '', username: ''),
        to: profileMap[toId] ?? UserModel(id: toId, name: '', username: ''),
        status: FriendRequestStatus.pending,
        createdAt: DbTime.parse(r['created_at']),
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
    _invalidateMyFriendsCache();
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
        .select(UserModel.dbColumns)
        .or('name.ilike.%$query%,username.ilike.%$query%')
        .neq('id', _uid)
        .limit(20);
    return (rows as List).map((r) => UserModel.fromMap(r)).toList();
  }

  // ── Messages ───────────────────────────────────────────────

  /// ID canônico da conversa: IDs dos dois usuários em ordem alfabética.
  /// Garante que A→B e B→A usem o mesmo chat_id na tabela messages.
  static String canonicalChatId(String otherUserId) {
    final ids = [_uid, otherUserId]..sort();
    return ids.join('_');
  }

  /// Quantas mensagens não lidas existem de cada contato (chave = remetente).
  /// Filtra pelo `chat_id` (que contém o meu id) em vez de confiar na RLS,
  /// então a contagem é das MINHAS conversas mesmo.
  static Future<Map<String, int>> getUnreadCounts() async {
    final uid = _uid;
    if (uid.isEmpty) return {};
    final rows = await _db
        .from('messages')
        .select('sender_id')
        .like('chat_id', '%$uid%')
        .eq('is_read', false)
        .neq('sender_id', uid);

    final counts = <String, int>{};
    for (final r in (rows as List)) {
      final s = (r as Map<String, dynamic>)['sender_id'] as String?;
      if (s == null) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  /// Marca como lidas as mensagens RECEBIDAS na conversa com [otherUserId].
  static Future<void> markChatRead(String otherUserId) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    await _db
        .from('messages')
        .update({'is_read': true})
        .eq('chat_id', canonicalChatId(otherUserId))
        .eq('is_read', false)
        .neq('sender_id', uid);
  }

  /// Carrega as últimas [limit] mensagens da conversa, em ordem cronológica
  /// ascendente. Limite padrão evita consumir memória em conversas longas.
  static Future<List<MessageModel>> getMessages(
    String otherUserId, {
    int limit = 100,
  }) async {
    final chatId = canonicalChatId(otherUserId);
    // Pega as últimas N (desc), depois inverte para renderizar na ordem certa.
    final rows = await _db
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_fkey(name, avatar_url)')
        .eq('chat_id', chatId)
        .order('sent_at', ascending: false)
        .limit(limit);

    // Decifra cada mensagem no aparelho (E2EE). O envelope é aberto com a
    // chave do dispositivo que ENVIOU — por isso passamos o sender_id (que
    // pode ser eu mesmo, nas mensagens que mandei).
    final list = await Future.wait((rows as List).map((r) async {
      final row = r as Map<String, dynamic>;
      final clear = await ChatKeyService.decryptFrom(
          row['sender_id'] as String? ?? otherUserId,
          row['content'] as String? ?? '');
      return _rowToMessage(row, chatId, contentOverride: clear);
    }));
    return list.reversed.toList();
  }

  static Future<MessageModel> sendMessage(String otherUserId, String content,
      {String? imageUrl}) async {
    final chatId = canonicalChatId(otherUserId);
    // E2EE: cifra o texto antes de gravar (só texto; imagem vai pelo storage).
    final storedContent =
        content.isEmpty ? '' : await ChatKeyService.encryptFor(otherUserId, content);

    final row = await _db.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _uid,
      'content': storedContent,
      if (imageUrl != null) 'image_url': imageUrl,
    }).select('*, sender:profiles!messages_sender_id_fkey(name, avatar_url)').single();

    // Notifica o destinatário (best-effort). Sem o texto — o servidor não pode
    // ler o conteúdo (E2EE), então a notificação é genérica.
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
        'body': imageUrl != null ? '📷 Imagem' : '📩 Nova mensagem',
        'data': {'fromUserId': _uid, 'fromName': senderName},
      });
    } catch (_) {}

    // Devolve o modelo com o TEXTO em claro (o que o usuário digitou), pra UI.
    return _rowToMessage(row, chatId, contentOverride: content);
  }

  static Future<String> uploadChatImage(
      String otherUserId, Uint8List bytes, String extension) async {
    final chatId = canonicalChatId(otherUserId);
    // Comprime para JPEG ≤ 360KB antes de subir.
    final jpeg = await ImageUtils.compressToJpeg(bytes);
    final path =
        'chat/$chatId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from('chat-images').uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );
    // Formato público de propósito, mesmo com o bucket privado: é o que fica
    // gravado em `messages.image_url`, e [chatImageUrl] tira o caminho dele.
    final url = _db.storage.from('chat-images').getPublicUrl(path);
    // Pré-popula o cache local com os bytes que já temos, pra quem ENVIA não
    // precisar baixar de novo. Quem RECEBE cacheia ao visualizar (CachedNetworkImage).
    await ImageUtils.cacheBytes(url, jpeg);
    return url;
  }

  // ── Imagem do chat: URL assinada (migration 043) ────────────
  // O bucket `chat-images` deixou de ser público. A URL gravada na mensagem
  // continua no formato público (nada a migrar no banco), e na hora de exibir
  // ela vira uma URL assinada — que o Storage só emite para quem participa da
  // conversa, pela policy `chat_images_storage_select`.

  static const _validadeAssinatura = Duration(hours: 1);

  /// Caminho → (URL assinada, quando expira). A lista de mensagens redesenha
  /// muito; sem isto, cada rolagem pediria uma assinatura nova.
  static final Map<String, ({String url, DateTime expira})> _assinadas = {};

  /// URL que dá para exibir para a imagem [stored] de uma mensagem.
  ///
  /// Se [stored] não for do bucket do chat (mensagem antiga, outro endereço),
  /// volta como veio.
  static Future<String> chatImageUrl(String stored) async {
    final path = StorageUtils.pathFromPublicUrl(stored, 'chat-images');
    if (path == null) return stored;
    final agora = DateTime.now();
    final c = _assinadas[path];
    if (c != null && signatureStillValid(c.expira, agora)) return c.url;
    final url = await _db.storage
        .from('chat-images')
        .createSignedUrl(path, _validadeAssinatura.inSeconds);
    _assinadas[path] = (url: url, expira: agora.add(_validadeAssinatura));
    return url;
  }

  /// Assinatura ainda serve se sobra folga até vencer: uma URL entregue a um
  /// segundo do fim quebraria a imagem no meio do download.
  @visibleForTesting
  static bool signatureStillValid(DateTime expira, DateTime agora) =>
      agora.isBefore(expira.subtract(const Duration(minutes: 5)));

  static MessageModel _rowToMessage(Map<String, dynamic> r, String chatId,
      {String? contentOverride}) {
    final sender = r['sender'] as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: r['id'] as String,
      senderId: r['sender_id'] as String,
      senderName: sender['name'] as String? ?? '',
      senderAvatar: sender['avatar_url'] as String?,
      content: contentOverride ?? (r['content'] as String? ?? ''),
      imageUrl: r['image_url'] as String?,
      sentAt: DbTime.parse(r['sent_at']),
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
            // Decifra no aparelho (E2EE) com a chave do dispositivo remetente.
            final clear = await ChatKeyService.decryptFrom(
                newRow['sender_id'] as String? ?? otherUserId,
                newRow['content'] as String? ?? '');
            onMessage(MessageModel(
              id: newRow['id'] as String,
              senderId: newRow['sender_id'] as String,
              senderName: profile?['name'] as String? ?? '',
              senderAvatar: profile?['avatar_url'] as String?,
              content: clear,
              imageUrl: newRow['image_url'] as String?,
              sentAt: DbTime.parse(newRow['sent_at']),
              chatId: chatId,
            ));
          },
        )
        .subscribe();
  }

}
