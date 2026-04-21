import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/message_model.dart';
import '../../../core/models/friend_request_model.dart';
import '../../../core/services/supabase_social_service.dart';

class SocialViewModel extends ChangeNotifier {
  List<UserModel> _friends = [];
  List<UserModel> _searchResults = [];
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = '';
  RealtimeChannel? _messageChannel;

  List<UserModel> get friends => _friends;
  List<UserModel> get searchResults => _searchResults;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;
  int get pendingCount => _receivedRequests.length;

  Future<void> loadFriends() async {
    _isLoading = true;
    notifyListeners();
    try {
      _friends = await SupabaseSocialService.getFriends();
    } catch (_) {
      _friends = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRequests() async {
    try {
      final results = await Future.wait([
        SupabaseSocialService.getReceivedRequests(),
        SupabaseSocialService.getSentRequests(),
      ]);
      _receivedRequests = results[0];
      _sentRequests = results[1];
      notifyListeners();
    } catch (_) {}
  }

  /// Loads friends and pending requests in parallel.
  Future<void> loadAll() async {
    await Future.wait([loadFriends(), loadRequests()]);
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    try {
      _searchResults = await SupabaseSocialService.searchUsers(query);
    } catch (_) {
      _searchResults = [];
    }
    _isSearching = false;
    notifyListeners();
  }

  Future<void> loadMessages(String otherUserId) async {
    // Cancela subscription anterior (outro chat aberto)
    _messageChannel?.unsubscribe();
    _messageChannel = null;
    _messages = [];
    notifyListeners();

    try {
      _messages = await SupabaseSocialService.getMessages(otherUserId);
      notifyListeners();
    } catch (_) {}

    // Inicia real-time para mensagens novas
    _messageChannel = SupabaseSocialService.subscribeToMessages(
      otherUserId,
      (msg) {
        // Evita duplicata da própria mensagem enviada via sendMessage
        if (!_messages.any((m) => m.id == msg.id)) {
          _messages = [..._messages, msg];
          notifyListeners();
        }
      },
    );
  }

  void unsubscribeMessages() {
    _messageChannel?.unsubscribe();
    _messageChannel = null;
  }

  Future<void> sendMessage(String otherUserId, String content) async {
    try {
      final msg = await SupabaseSocialService.sendMessage(otherUserId, content);
      _messages = [..._messages, msg];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendImage(
      String otherUserId, Uint8List bytes, String extension) async {
    try {
      final imageUrl = await SupabaseSocialService.uploadChatImage(
          otherUserId, bytes, extension);
      final msg = await SupabaseSocialService.sendMessage(otherUserId, '',
          imageUrl: imageUrl);
      _messages = [..._messages, msg];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> acceptRequest(String requestId) async {
    // Ignora se já foi aceito/removido (evita duplo-aceite via pedidos + notificação)
    if (!_receivedRequests.any((r) => r.id == requestId)) return;
    try {
      await SupabaseSocialService.acceptFriendRequest(requestId);
      _receivedRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
      await loadFriends();
    } catch (_) {}
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await SupabaseSocialService.rejectFriendRequest(requestId);
      _receivedRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendFriendRequest(String userId) async {
    try {
      await SupabaseSocialService.sendFriendRequest(userId);
    } catch (_) {}
  }
}
