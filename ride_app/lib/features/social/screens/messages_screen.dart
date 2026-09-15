import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/social_viewmodel.dart';

/// Aba Contatos: lista de amigos com o número de mensagens não lidas.
/// Toque no **nome/linha** abre a conversa; toque na **foto** abre o perfil.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final vm = context.read<SocialViewModel>();
      vm.loadFriends();
      vm.loadRequests(); // badge de pedidos de amizade no topo
      vm.loadUnreadCounts();
    });
  }

  Future<void> _refresh() async {
    final vm = context.read<SocialViewModel>();
    await Future.wait([vm.loadFriends(), vm.loadUnreadCounts()]);
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
        title: Text('Contatos',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        actions: [
          // Amigos e pedidos de amizade (saiu da barra inferior, mas continua
          // acessível aqui — com o contador de pedidos pendentes).
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.group_outlined, color: AppColors.navy),
                tooltip: 'Amigos e pedidos',
                onPressed: () => context.push('/friends'),
              ),
              if (vm.pendingCount > 0)
                Positioned(
                  top: 8,
                  right: 6,
                  child: _Badge(count: vm.pendingCount),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.person_add_alt_1, color: AppColors.navy),
            tooltip: 'Buscar riders',
            onPressed: () => context.push('/friends/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: _refresh,
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
                  final unread = vm.unreadBySender[f.id] ?? 0;
                  return ListTile(
                    // Linha/nome → conversa (e zera o badge).
                    onTap: () {
                      context.read<SocialViewModel>().markChatRead(f.id);
                      context.push('/friends/chat/${f.id}');
                    },
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    // Foto → perfil do rider.
                    leading: GestureDetector(
                      onTap: () =>
                          context.push('/profile/${f.id}', extra: f),
                      child: Stack(
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
                    ),
                    title: Text(f.name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      f.isOnline ? 'Online' : 'Toque para conversar',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                    trailing: unread > 0
                        ? _Badge(count: unread)
                        : Icon(Icons.chat_bubble_outline,
                            color: AppColors.navy, size: 20),
                  );
                },
              ),
      ),
    );
  }
}

/// Contador circular usado no badge de não-lidas e no de pedidos de amizade.
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
