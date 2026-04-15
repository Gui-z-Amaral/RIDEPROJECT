class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final String? chatId;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.sentAt,
    this.isRead = false,
    this.chatId,
  });
}
