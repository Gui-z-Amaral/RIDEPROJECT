class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String? imageUrl;
  final DateTime sentAt;
  final bool isRead;
  final String? chatId;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.imageUrl,
    required this.sentAt,
    this.isRead = false,
    this.chatId,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
