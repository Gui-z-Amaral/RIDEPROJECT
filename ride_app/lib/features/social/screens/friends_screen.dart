import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../shared/widgets/friend_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../viewmodels/social_viewmodel.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SocialViewModel>().loadFriends();
      context.read<SocialViewModel>().loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigos'),
        automaticallyImplyLeading: false,
        actions: [
          if (vm.pendingCount > 0)
            Stack(
              children: [
                IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/friends/invites')),
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Text('${vm.pendingCount}', style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 9)),
                  ),
                ),
              ],
            ),
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: () => context.push('/friends/search')),
        ],
      ),
      body: vm.isLoading
          ? const LoadingWidget()
          : vm.friends.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: 'Nenhum amigo ainda',
                  subtitle: 'Busque riders e adicione-os como amigos',
                  actionLabel: 'Buscar riders',
                  onAction: () => context.push('/friends/search'),
                )
              : ListView.separated(
                  itemCount: vm.friends.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final friend = vm.friends[i];
                    return FriendTile(
                      user: friend,
                      actions: const [FriendTileAction.chat],
                      onAction: () => context.push('/friends/chat/${friend.id}'),
                    );
                  },
                ),
    );
  }
}
