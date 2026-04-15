import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/friend_tile.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Riders'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppSearchInput(
              controller: _searchCtrl,
              hint: 'Buscar por nome ou @username',
              autofocus: true,
              onChanged: (q) => context.read<SocialViewModel>().search(q),
              onClear: () => context.read<SocialViewModel>().search(''),
            ),
          ),
          Expanded(
            child: vm.isSearching
                ? const LoadingWidget()
                : vm.searchQuery.isEmpty
                    ? const EmptyState(icon: Icons.search, title: 'Busque por riders', subtitle: 'Digite o nome ou @ de quem você quer encontrar')
                    : vm.searchResults.isEmpty
                        ? EmptyState(icon: Icons.person_search, title: 'Nenhum resultado', subtitle: 'Tente um nome diferente')
                        : ListView.separated(
                            itemCount: vm.searchResults.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (_, i) {
                              final user = vm.searchResults[i];
                              return FriendTile(
                                user: user,
                                actions: const [FriendTileAction.add],
                                onAction: () {
                                  vm.sendFriendRequest(user.id);
                                  context.showSnack('Solicitação enviada para ${user.name}!');
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
