import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/club_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/club_viewmodel.dart';

/// Aba Motoclubes: convites pendentes, meus clubes e descobrir novos.
class ClubsTabScreen extends StatefulWidget {
  const ClubsTabScreen({super.key});

  @override
  State<ClubsTabScreen> createState() => _ClubsTabScreenState();
}

class _ClubsTabScreenState extends State<ClubsTabScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ClubViewModel>().loadMine());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('Motoclubes',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppColors.navy),
            tooltip: 'Criar motoclube',
            onPressed: () => context.push('/clubs/create'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => context.read<ClubViewModel>().loadMine(),
        child: vm.isLoading && vm.myClubs.isEmpty && vm.invites.isEmpty
            ? Center(child: CircularProgressIndicator(color: AppColors.navy))
            : ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad + 100),
                children: [
                  if (vm.invites.isNotEmpty) ...[
                    const _SectionLabel('CONVITES'),
                    const SizedBox(height: 8),
                    ...vm.invites.map((c) => _InviteCard(club: c)),
                    const SizedBox(height: 24),
                  ],
                  const _SectionLabel('MEUS CLUBES'),
                  const SizedBox(height: 8),
                  if (vm.myClubs.isEmpty)
                    _EmptyMine(onCreate: () => context.push('/clubs/create'))
                  else
                    ...vm.myClubs.map((c) => _ClubCard(club: c)),
                  const SizedBox(height: 24),
                  if (vm.discover.isNotEmpty) ...[
                    const _SectionLabel('DESCOBRIR'),
                    const SizedBox(height: 8),
                    ...vm.discover.map((c) => _ClubCard(club: c)),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ));
  }
}

class _ClubCard extends StatelessWidget {
  final ClubModel club;
  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/clubs/${club.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _ClubAvatar(url: club.avatarUrl, name: club.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (club.location.isNotEmpty) club.location,
                      '${club.membersCount} ${club.membersCount == 1 ? 'membro' : 'membros'}',
                    ].join(' · '),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (club.isAdmin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(club.isOwner ? 'Dono' : 'Admin',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w700)),
              ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final ClubModel club;
  const _InviteCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ClubViewModel>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.navy.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ClubAvatar(url: club.avatarUrl, name: club.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name,
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text('Convidou você para o clube',
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
                child: OutlinedButton(
                  onPressed: () => vm.declineInvite(club.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Recusar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => vm.acceptInvite(club.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Aceitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClubAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _ClubAvatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.navy.withOpacity(0.1),
      backgroundImage: (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.isEmpty)
          ? Icon(Icons.shield_moon_outlined, color: AppColors.navy, size: 24)
          : null,
    );
  }
}

class _EmptyMine extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyMine({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.shield_moon_outlined,
              size: 44, color: AppColors.navy.withOpacity(0.4)),
          const SizedBox(height: 10),
          Text('Você ainda não está em nenhum motoclube',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Criar meu motoclube'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
