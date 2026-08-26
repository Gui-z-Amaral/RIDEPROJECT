import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/social_viewmodel.dart';

/// Aba Chat: lista de amigos para iniciar/continuar uma conversa.
/// (Versão simples — toca no amigo e abre o chat.)
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SocialViewModel>().loadFriends());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final friends = vm.friends;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('Mensagens',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1, color: AppColors.navy),
            tooltip: 'Buscar riders',
            onPressed: () => context.push('/friends/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => context.read<SocialViewModel>().loadFriends(),
        child: friends.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: AppColors.navy.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('Nenhuma conversa ainda',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Adicione amigos para conversar',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 24),
                itemCount: friends.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) {
                  final f = friends[i];
                  return ListTile(
                    onTap: () => context.push('/friends/chat/${f.id}'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.navy.withOpacity(0.1),
                          backgroundImage:
                              (f.avatarUrl != null && f.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(f.avatarUrl!)
                                  : null,
                          child: (f.avatarUrl == null || f.avatarUrl!.isEmpty)
                              ? Text(
                                  f.name.isNotEmpty
                                      ? f.name[0].toUpperCase()
                                      : '?',
                                  style: AppTextStyles.titleMedium
                                      .copyWith(color: AppColors.navy))
                              : null,
                        ),
                        if (f.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.background, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(f.name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      f.isOnline ? 'Online' : 'Toque para conversar',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    trailing: Icon(Icons.chat_bubble_outline,
                        color: AppColors.navy, size: 20),
                  );
                },
              ),
      ),
    );
  }
}
