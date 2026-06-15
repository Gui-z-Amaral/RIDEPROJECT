import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/social_viewmodel.dart';
import '../../../core/models/session_invite.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/utils/extensions.dart';
import '../../trips/viewmodels/trip_viewmodel.dart';
import '../../rides/viewmodels/ride_viewmodel.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  List<SessionInvite> _sessionInvites = [];
  bool _respondingId = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SocialViewModel>().loadRequests();
      _loadSessionInvites();
    });
  }

  Future<void> _loadSessionInvites() async {
    try {
      final results = await Future.wait([
        SupabaseRideService.getPendingInvites(),
        SupabaseTripService.getPendingInvites(),
      ]);
      if (!mounted) return;
      setState(() => _sessionInvites = [...results[0], ...results[1]]);
    } catch (_) {
      if (mounted) setState(() => _sessionInvites = []);
    }
  }

  Future<void> _respondSession(SessionInvite invite, bool accept) async {
    if (_respondingId) return;
    setState(() => _respondingId = true);
    try {
      if (invite.isRide) {
        accept
            ? await SupabaseRideService.confirmParticipation(invite.sessionId)
            : await SupabaseRideService.declineParticipation(invite.sessionId);
      } else {
        accept
            ? await SupabaseTripService.confirmParticipation(invite.sessionId)
            : await SupabaseTripService.declineParticipation(invite.sessionId);
      }
      if (mounted) {
        setState(() =>
            _sessionInvites.removeWhere((i) => i.sessionId == invite.sessionId));
        // Atualiza as listas pra refletir na hora (sem precisar reentrar).
        if (invite.isRide) {
          context.read<RideViewModel>().loadRides();
        } else {
          context.read<TripViewModel>().loadTrips();
        }
        context.showSnack(accept
            ? 'Convite aceito! Você entrou ${invite.isRide ? 'no rolê' : 'na viagem'}.'
            : 'Convite recusado.');
      }
    } catch (_) {
      if (mounted) context.showSnack('Erro ao responder. Tente novamente.', isError: true);
    } finally {
      if (mounted) setState(() => _respondingId = false);
    }
  }

  Widget _sectionLabel(String text) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Text(text,
              style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ),
      );

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

          // ── Rolês e viagens ──────────────────────────────────────
          if (_sessionInvites.isNotEmpty) ...[
            _sectionLabel('ROLÊS E VIAGENS'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final inv = _sessionInvites[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _SessionInviteCard(
                      invite: inv,
                      onAccept: () => _respondSession(inv, true),
                      onReject: () => _respondSession(inv, false),
                    ),
                  );
                },
                childCount: _sessionInvites.length,
              ),
            ),
          ],

          // ── Amizades ─────────────────────────────────────────────
          if (vm.receivedRequests.isNotEmpty) ...[
            _sectionLabel('AMIZADES'),
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
          ],

          // ── Empty state (nenhum convite de nenhum tipo) ──────────
          if (_sessionInvites.isEmpty && vm.receivedRequests.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
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

// ─── Card de convite de rolê/viagem ───────────────────────────────────────────

class _SessionInviteCard extends StatelessWidget {
  final SessionInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SessionInviteCard({
    required this.invite,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final accent = invite.isRide ? const Color(0xFF9C6FE4) : AppColors.teal;
    final icon = invite.isRide ? Icons.groups : Icons.map_outlined;
    final tipo = invite.isRide ? 'Rolê' : 'Viagem';
    final d = invite.scheduledAt;
    final dateLabel = d != null
        ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Convite de $tipo',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: accent, fontWeight: FontWeight.w800)),
                    Text(invite.title,
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (dateLabel != null)
                      Text(dateLabel,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  child: Text('ACEITAR',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.navy, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('RECUSAR',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.navy, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
