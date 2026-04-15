import 'package:flutter/material.dart';
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
      _receivedRequests = results[0] as List<FriendRequestModel>;
      _sentRequests = results[1] as List<FriendRequestModel>;
      notifyListeners();
    } catch (_) {}
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

  Future<void> loadMessages(String chatId) async {
    try {
      _messages = await SupabaseSocialService.getMessages(chatId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendMessage(String chatId, String content) async {
    try {
      final msg = await SupabaseSocialService.sendMessage(chatId, content);
      _messages = [..._messages, msg];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> acceptRequest(String requestId) async {
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
