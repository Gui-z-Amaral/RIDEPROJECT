import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../../../core/models/message_model.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/supabase_notification_service.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/services/supabase_social_service.dart';
import '../../../core/constants/text_limits.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sendingImage = false;
  SocialViewModel? _socialVm;

  @override
  void initState() {
    super.initState();
    // Marca este chat como ativo → não exibe push de mensagem desta pessoa.
    PushNotificationService.activeChatUserId = widget.userId;
    Future.microtask(() {
      if (!mounted) return;
      final vm = context.read<SocialViewModel>();
      vm.loadMessages(widget.userId);
      // Abriu a conversa → zera o contador de não lidas deste contato
      // (vale também quando o chat é aberto pelo push, não só pela lista).
      vm.markChatRead(widget.userId);
      // ...e limpa as notificações acumuladas desta pessoa: o usuário está
      // lendo a conversa agora, não faz sentido continuarem na lista.
      SupabaseNotificationService.clearMessageNotificationsFrom(widget.userId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _socialVm = context.read<SocialViewModel>();
  }

  @override
  void dispose() {
    // Só limpa se ainda for este chat (evita corrida ao abrir outro).
    if (PushNotificationService.activeChatUserId == widget.userId) {
      PushNotificationService.activeChatUserId = null;
    }
    _socialVm?.unsubscribeMessages();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Lista é reverse:true → a mensagem mais recente fica no offset mínimo (0).
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    try {
      await context.read<SocialViewModel>().sendMessage(widget.userId, text);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Restaura o texto para o usuário não perder o que digitou
      _msgCtrl.text = text;
      // StateError do E2EE traz mensagem amigável (ex: contato sem chave
      // publicada porque ainda não abriu o app novo) — mostra ela.
      final msg = e is StateError
          ? '${e.message} A mensagem será possível assim que ele abrir o app.'
          : 'Erro ao enviar mensagem';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await _showImageSourceSheet();
    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _sendingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      await context
          .read<SocialViewModel>()
          .sendImage(widget.userId, bytes, ext);
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao enviar imagem'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<ImageSource?> _showImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined,
                    color: AppColors.navy),
                title: Text('Câmera', style: AppTextStyles.titleMedium),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: AppColors.navy),
                title: Text('Galeria', style: AppTextStyles.titleMedium),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final friend =
        vm.friends.where((u) => u.id == widget.userId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: friend == null
            ? Text('Chat',
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.w800))
            : Row(
                children: [
                  AppAvatar(
                    name: friend.name,
                    imageUrl: friend.avatarUrl,
                    size: 40,
                    profileOf: friend,
                    showOnline: true,
                    isOnline: friend.isOnline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.name,
                            style: AppTextStyles.titleLarge
                                .copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                        Text(
                          friend.isOnline ? 'Online' : 'Offline',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: friend.isOnline
                                ? AppColors.online
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              // Invertida: ancora na mensagem mais recente (embaixo) ao abrir
              // e ao chegar mensagem nova, sem precisar rolar manualmente.
              reverse: true,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              itemCount: vm.messages.length,
              itemBuilder: (_, i) {
                // i=0 é a mais recente (fica embaixo na lista invertida).
                final msg = vm.messages[vm.messages.length - 1 - i];
                final isMe = msg.senderId == myId;
                return _ChatBubble(
                  msg: msg,
                  isMe: isMe,
                  onImageTap: () => _showFullImage(context, msg.imageUrl!),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
                color: AppColors.surface,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  // Botão de imagem
                  _sendingImage
                      ? SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.navy),
                          ),
                        )
                      : GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.image_outlined,
                                color: AppColors.navy, size: 20),
                          ),
                        ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      // O banco limita o envelope cifrado; este é o limite do
                      // texto, com folga para caber no envelope.
                      maxLength: TextLimits.mensagem,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      style: AppTextStyles.bodyLarge,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Mensagem...',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.navy, shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullImage(BuildContext context, String imageUrl) async {
    // O bucket do chat é privado (migration 043): o visualizador recebe a URL
    // assinada, não a gravada na mensagem.
    try {
      final url = await SupabaseSocialService.chatImageUrl(imageUrl);
      if (!context.mounted) return;
      showPhotoViewer(context, urls: [url]);
    } catch (_) {
      if (context.mounted) {
        context.showSnack('Não foi possível abrir a imagem.', isError: true);
      }
    }
  }
}

// ── Bolha de mensagem ─────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final VoidCallback onImageTap;

  const _ChatBubble(
      {required this.msg, required this.isMe, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppColors.navy : AppColors.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusLg),
            topRight: const Radius.circular(AppSpacing.radiusLg),
            bottomLeft: isMe
                ? const Radius.circular(AppSpacing.radiusLg)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(AppSpacing.radiusLg),
          ),
          // Sem padding na bolha de imagem pura, padding só no container interno
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.hasImage)
              GestureDetector(
                onTap: onImageTap,
                child: Stack(
                  children: [
                    _ChatImage(
                      stored: msg.imageUrl!,
                    ),
                    // Ícone de lupa para indicar que expande
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.zoom_in,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.content.isNotEmpty) ...[
                    Text(
                      msg.content,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color:
                              isMe ? Colors.white : AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    msg.sentAt.formattedTime,
                    style: AppTextStyles.labelSmall.copyWith(
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Imagem do chat ────────────────────────────────────────────────────────────
/// Imagem de uma mensagem. Pede a URL assinada antes de desenhar: desde a
/// migration 043 o bucket do chat é privado, e a URL gravada na mensagem já não
/// abre sozinha.
///
/// O `cacheKey` é a URL gravada, não a assinada: a assinatura muda a cada
/// hora, e sem isso a mesma foto seria baixada de novo toda vez. Também é o
/// que faz o cache que quem ENVIOU já preencheu (ImageUtils.cacheBytes) valer.
class _ChatImage extends StatefulWidget {
  final String stored;
  const _ChatImage({required this.stored});

  @override
  State<_ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<_ChatImage> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = SupabaseSocialService.chatImageUrl(widget.stored);
  }

  @override
  void didUpdateWidget(_ChatImage old) {
    super.didUpdateWidget(old);
    if (old.stored != widget.stored) {
      _url = SupabaseSocialService.chatImageUrl(widget.stored);
    }
  }

  Widget _placeholder() => Container(
        height: 180,
        color: AppColors.inputFill,
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.navy, strokeWidth: 2)),
      );

  Widget _erro() => Container(
        height: 100,
        color: AppColors.inputFill,
        child: Center(
            child: Icon(Icons.broken_image, color: AppColors.textMuted)),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) return _erro();
        final url = snap.data;
        if (url == null) return _placeholder();
        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: widget.stored,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
          placeholder: (_, __) => _placeholder(),
          errorWidget: (_, __, ___) => _erro(),
        );
      },
    );
  }
}
