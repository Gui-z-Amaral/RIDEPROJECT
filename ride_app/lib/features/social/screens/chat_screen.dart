import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../core/services/mock_data.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SocialViewModel>().loadMessages(widget.userId));
  }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<SocialViewModel>().sendMessage(widget.userId, text);
    _msgCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    final friend = MockData.users.firstWhere((u) => u.id == widget.userId, orElse: () => MockData.users.first);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
        title: Row(
          children: [
            AppAvatar(name: friend.name, imageUrl: friend.avatarUrl, size: 36, showOnline: true, isOnline: friend.isOnline),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, style: AppTextStyles.titleLarge),
                Text(friend.isOnline ? 'Online' : 'Offline', style: AppTextStyles.labelSmall.copyWith(color: friend.isOnline ? AppColors.online : AppColors.textMuted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () => context.push('/calls/voice/${friend.id}')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              itemCount: vm.messages.length,
              itemBuilder: (_, i) {
                final msg = vm.messages[i];
                final isMe = msg.senderId == 'u1';
                return _ChatBubble(content: msg.content, isMe: isMe, time: msg.sentAt.formattedTime);
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider)), color: AppColors.surface),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: AppTextStyles.bodyLarge,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Mensagem...',
                      hintStyle: AppTextStyles.bodyMedium,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusFull), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: AppColors.deepNavy, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String time;

  const _ChatBubble({required this.content, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isMe ? AppColors.teal : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusLg),
            topRight: const Radius.circular(AppSpacing.radiusLg),
            bottomLeft: isMe ? const Radius.circular(AppSpacing.radiusLg) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(content, style: AppTextStyles.bodyMedium.copyWith(color: isMe ? AppColors.deepNavy : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(time, style: AppTextStyles.labelSmall.copyWith(color: isMe ? AppColors.deepNavy.withOpacity(0.7) : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
