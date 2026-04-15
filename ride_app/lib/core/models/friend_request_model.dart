import 'user_model.dart';

enum FriendRequestStatus { pending, accepted, rejected }

class FriendRequestModel {
  final String id;
  final UserModel from;
  final UserModel to;
  final FriendRequestStatus status;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.id,
    required this.from,
    required this.to,
    this.status = FriendRequestStatus.pending,
    required this.createdAt,
  });
}
