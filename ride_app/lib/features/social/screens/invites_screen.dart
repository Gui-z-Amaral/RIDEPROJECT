import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../shared/widgets/friend_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    Future.microtask(() => context.read<SocialViewModel>().loadRequests());
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitações'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.teal,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(text: 'Recebidas (${vm.receivedRequests.length})'),
            Tab(text: 'Enviadas (${vm.sentRequests.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          vm.receivedRequests.isEmpty
              ? const EmptyState(icon: Icons.inbox, title: 'Nenhuma solicitação', subtitle: 'Você não tem solicitações pendentes')
              : ListView.separated(
                  itemCount: vm.receivedRequests.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final req = vm.receivedRequests[i];
                    return FriendTile(
                      user: req.from,
                      actions: const [FriendTileAction.accept, FriendTileAction.reject],
                      onAction: () { vm.acceptRequest(req.id); context.showSnack('Você e ${req.from.name} agora são amigos!'); },
                      onSecondaryAction: () => vm.rejectRequest(req.id),
                    );
                  },
                ),
          vm.sentRequests.isEmpty
              ? const EmptyState(icon: Icons.send, title: 'Nenhuma enviada', subtitle: 'Busque riders para adicionar')
              : ListView.separated(
                  itemCount: vm.sentRequests.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) => FriendTile(user: vm.sentRequests[i].to, actions: const []),
                ),
        ],
      ),
    );
  }
}
