import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/friend_request_model.dart';
import 'mock_data.dart';

class MockSocialService {
  static Future<List<UserModel>> getFriends() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.friends;
  }

  static Future<List<UserModel>> searchUsers(String query) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (query.isEmpty) return [];
    return MockData.users
        .where((u) =>
            u.name.toLowerCase().contains(query.toLowerCase()) ||
            u.username.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  static Future<List<FriendRequestModel>> getReceivedRequests() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      FriendRequestModel(
        id: 'fr1',
        from: MockData.users[4],
        to: MockData.currentUser,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      FriendRequestModel(
        id: 'fr2',
        from: MockData.users[5],
        to: MockData.currentUser,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  static Future<List<FriendRequestModel>> getSentRequests() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      FriendRequestModel(
        id: 'fr3',
        from: MockData.currentUser,
        to: MockData.users[6],
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ];
  }

  static Future<void> sendFriendRequest(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  static Future<void> rejectFriendRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  static Future<List<MessageModel>> getMessages(String chatId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.getMessages(chatId);
  }

  static Future<void> sendMessage(String chatId, String content) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
