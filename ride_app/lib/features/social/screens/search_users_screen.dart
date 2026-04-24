import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() {}); // atualiza o X imediatamente
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<SocialViewModel>().search(q.trim());
    });
  }

  void _clear() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() {});
    context.read<SocialViewModel>().search('');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    final hasQuery = _searchCtrl.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Buscar Riders',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: vm.isSearching
              ? const LinearProgressIndicator(
                  color: AppColors.navy,
                  backgroundColor: AppColors.divider,
                  minHeight: 2,
                )
              : const SizedBox(height: 1),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onChanged,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou @username',
                  hintStyle: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textMuted, size: 22),
                  suffixIcon: hasQuery
                      ? GestureDetector(
                          onTap: _clear,
                          child: const Icon(Icons.close,
                              color: AppColors.textMuted, size: 20),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 14),
                ),
              ),
            ),
          ),

          // ── Results ────────────────────────────────────────────
          Expanded(
            child: !hasQuery
                // Estado inicial — ainda não digitou nada
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search,
                            size: 56,
                            color: AppColors.textMuted.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('Busque por riders',
                            style: AppTextStyles.titleLarge
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                            'Digite o nome ou @ de quem você quer encontrar',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : vm.searchResults.isEmpty && !vm.isSearching
                    // Nenhum resultado (e não está carregando)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search,
                                size: 56,
                                color: AppColors.textMuted.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text('Nenhum resultado',
                                style: AppTextStyles.titleLarge
                                    .copyWith(
                                        color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            Text('Tente um nome ou username diferente',
                                style: AppTextStyles.bodySmall
                                    .copyWith(
                                        color: AppColors.textMuted)),
                          ],
                        ),
                      )
                    // Lista de resultados (mantém visível enquanto isSearching)
                    : ListView.separated(
                        padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).padding.bottom + 16),
                        itemCount: vm.searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 66),
                        itemBuilder: (_, i) {
                          final user = vm.searchResults[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.sm),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppColors.navy.withOpacity(0.1),
                              backgroundImage: user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(
                                      user.name.isNotEmpty
                                          ? user.name[0].toUpperCase()
                                          : '?',
                                      style: AppTextStyles.titleMedium
                                          .copyWith(color: AppColors.navy),
                                    )
                                  : null,
                            ),
                            title: Text(user.name,
                                style: AppTextStyles.titleMedium),
                            subtitle: user.username.isNotEmpty
                                ? Text('@${user.username}',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(
                                            color: AppColors.textMuted))
                                : null,
                            trailing: _AddButton(
                              onTap: () {
                                context
                                    .read<SocialViewModel>()
                                    .sendFriendRequest(user.id);
                                context.showSnack(
                                    'Solicitação enviada para ${user.name}!');
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _sent
          ? null
          : () {
              setState(() => _sent = true);
              widget.onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _sent ? AppColors.divider : AppColors.navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _sent ? 'Enviado' : 'Adicionar',
          style: AppTextStyles.labelSmall.copyWith(
            color: _sent ? AppColors.textMuted : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
