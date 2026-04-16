import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SocialViewModel>().loadRequests());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SocialViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.navy, size: 24),
                ),
                const Spacer(),
                Text('HOME',
                    style: AppTextStyles.headlineMedium
                        .copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONVITES RECEBIDOS',
                      style: AppTextStyles.headlineLarge.copyWith(
                          fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    'Veja os convites que você recebeu de seus contatos',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Lista de convites ────────────────────────────────────
          if (vm.receivedRequests.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 56,
                        color: AppColors.textMuted.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text('Nenhum convite pendente',
                        style: AppTextStyles.titleLarge
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final req = vm.receivedRequests[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _InviteCard(
                      avatarUrl: req.from.avatarUrl,
                      name: req.from.name,
                      username: req.from.username,
                      createdAt: req.createdAt,
                      onAccept: () {
                        vm.acceptRequest(req.id);
                        context.showSnack(
                            'Você e ${req.from.name} agora são amigos!');
                      },
                      onReject: () => vm.rejectRequest(req.id),
                    ),
                  );
                },
                childCount: vm.receivedRequests.length,
              ),
            ),

          // ── Enviadas ─────────────────────────────────────────────
          if (vm.sentRequests.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 8),
                child: Text('CONVITES ENVIADOS',
                    style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final req = vm.sentRequests[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _SentRequestCard(
                      avatarUrl: req.to.avatarUrl,
                      name: req.to.name,
                      username: req.to.username,
                    ),
                  );
                },
                childCount: vm.sentRequests.length,
              ),
            ),
          ],

          SliverToBoxAdapter(
              child: SizedBox(height: bottomPad + 80)),
        ],
      ),
    );
  }
}

// ─── Invite card (recebido) ───────────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String username;
  final DateTime createdAt;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InviteCard({
    required this.avatarUrl,
    required this.name,
    required this.username,
    required this.createdAt,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.navy.withOpacity(0.1),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                if (username.isNotEmpty)
                  Text('@$username',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Text(
                  '${createdAt.day.toString().padLeft(2, '0')} de ${_month(createdAt.month)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 12),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: Text('ACEITAR',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.navy, width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text('RECUSAR',
                            style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _month(int m) => const [
        '',
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro'
      ][m];
}

// ─── Sent request card ────────────────────────────────────────────────────────

class _SentRequestCard extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String username;
  const _SentRequestCard(
      {required this.avatarUrl,
      required this.name,
      required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.navy.withOpacity(0.1),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleMedium),
                if (username.isNotEmpty)
                  Text('@$username',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Pendente',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}
