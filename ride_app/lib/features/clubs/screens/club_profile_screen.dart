import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/club_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_club_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/club_viewmodel.dart';

/// Perfil do motoclube com abas internas: Sobre · Membros · Eventos · Viagens.
class ClubProfileScreen extends StatefulWidget {
  final String clubId;
  const ClubProfileScreen({super.key, required this.clubId});

  @override
  State<ClubProfileScreen> createState() => _ClubProfileScreenState();
}

class _ClubProfileScreenState extends State<ClubProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<ClubViewModel>().loadDetail(widget.clubId));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    final club = vm.selected;

    if (vm.isLoadingDetail && club == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }
    if (club == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Clube não encontrado.')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
            onPressed: () => context.pop(),
          ),
          actions: [_ClubMenu(club: club)],
          bottom: TabBar(
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.navy,
            labelStyle:
                AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Sobre'),
              Tab(text: 'Membros'),
              Tab(text: 'Atividades'),
            ],
          ),
        ),
        body: Column(
          children: [
            _ClubHeader(club: club),
            Expanded(
              child: TabBarView(
                children: [
                  _AboutTab(club: club),
                  _MembersTab(club: club),
                  _ActivitiesTab(club: club),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _ClubHeader extends StatelessWidget {
  final ClubModel club;
  const _ClubHeader({required this.club});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.navy.withOpacity(0.1),
            backgroundImage: (club.avatarUrl != null && club.avatarUrl!.isNotEmpty)
                ? NetworkImage(club.avatarUrl!)
                : null,
            child: (club.avatarUrl == null || club.avatarUrl!.isEmpty)
                ? Icon(Icons.shield_moon_outlined,
                    color: AppColors.navy, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.name,
                    style: AppTextStyles.headlineSmall
                        .copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (club.location.isNotEmpty) club.location,
                    '${club.membersCount} ${club.membersCount == 1 ? 'membro' : 'membros'}',
                  ].join(' · '),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aba Sobre ───────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final ClubModel club;
  const _AboutTab({required this.club});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        if ((club.description ?? '').isNotEmpty) ...[
          Text('Sobre',
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(club.description!,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
        ],
        if (club.location.isNotEmpty)
          _InfoRow(icon: Icons.place_outlined, text: club.location),
        _InfoRow(
            icon: Icons.groups_outlined,
            text:
                '${club.membersCount} ${club.membersCount == 1 ? 'membro' : 'membros'}'),
        if (club.isActiveMember && !club.isOwner) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await _confirm(context, 'Sair do clube',
                  'Deseja sair de "${club.name}"?');
              if (ok && context.mounted) {
                await context.read<ClubViewModel>().leave(club.id);
                if (context.mounted) context.pop();
              }
            },
            icon: Icon(Icons.logout, color: AppColors.error),
            label: Text('Sair do clube',
                style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

// ─── Aba Membros ─────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final ClubModel club;
  const _MembersTab({required this.club});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    return Column(
      children: [
        if (club.isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInviteSheet(context, club),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Convidar membro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, 40 + MediaQuery.of(context).padding.bottom),
            itemCount: vm.members.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.divider, height: 1),
            itemBuilder: (_, i) => _MemberTile(member: vm.members[i], club: club),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ClubMemberModel member;
  final ClubModel club;
  const _MemberTile({required this.member, required this.club});

  @override
  Widget build(BuildContext context) {
    final u = member.user;
    final name = u?.name ?? 'Membro';
    final canRemove = club.isAdmin && !member.isOwner && member.userId != club.ownerId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.navy.withOpacity(0.1),
        backgroundImage: (u?.avatarUrl != null && u!.avatarUrl!.isNotEmpty)
            ? NetworkImage(u.avatarUrl!)
            : null,
        child: (u?.avatarUrl == null || (u?.avatarUrl?.isEmpty ?? true))
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.navy))
            : null,
      ),
      title: Text(name, style: AppTextStyles.bodyMedium),
      subtitle: member.isAdmin
          ? Text(member.isOwner ? 'Dono' : 'Admin',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.navy, fontWeight: FontWeight.w700))
          : null,
      trailing: canRemove
          ? IconButton(
              icon: Icon(Icons.remove_circle_outline, color: AppColors.textMuted),
              tooltip: 'Remover',
              onPressed: () async {
                final ok = await _confirm(context, 'Remover membro',
                    'Remover $name do clube?');
                if (ok && context.mounted) {
                  await context.read<ClubViewModel>().removeMember(member.userId);
                }
              },
            )
          : null,
    );
  }
}

void _openInviteSheet(BuildContext context, ClubModel club) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _InviteSheet(club: club),
  );
}

class _InviteSheet extends StatefulWidget {
  final ClubModel club;
  const _InviteSheet({required this.club});
  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _searching = false;
  final Set<String> _invited = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (q.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      try {
        final r = await SupabaseClubService.searchUsers(q);
        if (mounted) setState(() => _results = r);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _invite(UserModel u) async {
    final ok = await context
        .read<ClubViewModel>()
        .inviteUser(widget.club.id, u.id, widget.club.name);
    if (!mounted) return;
    if (ok) {
      setState(() => _invited.add(u.id));
      context.showSnack('Convite enviado para ${u.name}.');
    } else {
      context.showSnack('Não foi possível convidar (talvez já seja membro).',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Convidar membro', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou @usuário',
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: _searching
                ? Center(child: CircularProgressIndicator(color: AppColors.navy))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      final done = _invited.contains(u.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.navy.withOpacity(0.1),
                          backgroundImage:
                              (u.avatarUrl != null && u.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(u.avatarUrl!)
                                  : null,
                          child: (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                              ? Text(
                                  u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                  style: AppTextStyles.titleMedium
                                      .copyWith(color: AppColors.navy))
                              : null,
                        ),
                        title: Text(u.name, style: AppTextStyles.bodyMedium),
                        subtitle: u.username.isNotEmpty
                            ? Text('@${u.username}',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.textMuted))
                            : null,
                        trailing: done
                            ? Icon(Icons.check, color: AppColors.success)
                            : TextButton(
                                onPressed: () => _invite(u),
                                child: const Text('Convidar'),
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

// ─── Aba Atividades (mural único: eventos + viagens) ─────────────────────────

class _ActivitiesTab extends StatefulWidget {
  final ClubModel club;
  const _ActivitiesTab({required this.club});
  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final vm = context.read<ClubViewModel>();
      vm.loadClubEvents(widget.club.id);
      vm.loadClubTrips(widget.club.id);
    });
  }

  Future<void> _reload() async {
    final vm = context.read<ClubViewModel>();
    await vm.loadClubEvents(widget.club.id);
    await vm.loadClubTrips(widget.club.id);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    final club = widget.club;

    // Une eventos e viagens numa lista só, ordenada por data (próximos primeiro).
    final items = <_Activity>[
      ...vm.clubEvents.map((e) => _Activity(
            date: e.startsAt,
            card: _MuralCard(
              icon: Icons.event,
              title: e.title,
              subtitle: [
                'Evento',
                if ((e.city ?? '').isNotEmpty) e.city!,
                _fmtDate(e.startsAt),
              ].where((s) => s.isNotEmpty).join(' · '),
              myRsvp: vm.myEventRsvp[e.id],
              onRsvp: (r) => vm.setEventRsvp(e.id, r),
              onOpen: () => context.push('/events/${e.id}'),
              onAttendance: () => _openAttendance(context,
                  isTrip: false,
                  id: e.id,
                  title: e.title,
                  canCheckIn: club.isAdmin),
              showAttendance: club.isActiveMember,
            ),
          )),
      ...vm.clubTrips.map((t) {
        final city = t.destination.address?.split(',').first.trim() ??
            t.destination.label ??
            '';
        return _Activity(
          date: t.scheduledAt,
          card: _MuralCard(
            icon: Icons.route,
            title: t.title,
            subtitle: [
              'Viagem',
              if (city.isNotEmpty) city,
              _fmtDate(t.scheduledAt),
            ].where((s) => s.isNotEmpty).join(' · '),
            myRsvp: vm.myTripRsvp[t.id],
            onRsvp: (r) => vm.setTripRsvp(t.id, r),
            onOpen: () => context.push('/trips/${t.id}'),
            onRoteiro: () => context.push('/trips/${t.id}/schedule',
                extra: {'canEdit': club.isAdmin, 'title': t.title}),
            onAttendance: () => _openAttendance(context,
                isTrip: true, id: t.id, title: t.title, canCheckIn: club.isAdmin),
            showAttendance: club.isActiveMember,
          ),
        );
      }),
    ];
    // Ordena por data; itens sem data vão para o fim.
    items.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });

    final loading = vm.isLoadingEvents || vm.isLoadingTrips;
    return _MuralScaffold(
      isAdmin: club.isAdmin,
      createLabel: 'Criar atividade',
      onCreate: () async {
        await _chooseActivity(context, club);
        if (mounted) await _reload();
      },
      isLoading: loading,
      isEmpty: items.isEmpty,
      emptyLabel: 'Nenhuma atividade do clube ainda',
      onRefresh: _reload,
      children: items.map((a) => a.card).toList(),
    );
  }
}

class _Activity {
  final DateTime? date;
  final Widget card;
  const _Activity({required this.date, required this.card});
}

/// Escolhe o tipo de atividade (evento ou viagem) antes de criar.
Future<void> _chooseActivity(BuildContext context, ClubModel club) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text('Nova atividade do clube',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text('O que você quer criar?',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 18),
          _ActivityOption(
            icon: Icons.event,
            title: 'Evento',
            subtitle: 'Encontro com local, data e programação',
            onTap: () => Navigator.pop(sheetCtx, 'event'),
          ),
          const SizedBox(height: 12),
          _ActivityOption(
            icon: Icons.route,
            title: 'Viagem',
            subtitle: 'Roteiro com origem, destino e paradas',
            onTap: () => Navigator.pop(sheetCtx, 'trip'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final path = choice == 'event' ? '/events/create' : '/trips/create';
  await context.push(path, extra: {'clubId': club.id});
}

class _ActivityOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActivityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.navy, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleLarge),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

void _openAttendance(
  BuildContext context, {
  required bool isTrip,
  required String id,
  required String title,
  required bool canCheckIn,
}) {
  context.push('/attendance', extra: {
    'isTrip': isTrip,
    'id': id,
    'title': title,
    'canCheckIn': canCheckIn,
  });
}

// ─── Scaffold comum dos murais ───────────────────────────────────────────────

class _MuralScaffold extends StatelessWidget {
  final bool isAdmin;
  final String createLabel;
  final VoidCallback onCreate;
  final bool isLoading;
  final bool isEmpty;
  final String emptyLabel;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const _MuralScaffold({
    required this.isAdmin,
    required this.createLabel,
    required this.onCreate,
    required this.isLoading,
    required this.isEmpty,
    required this.emptyLabel,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(createLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.navy,
            onRefresh: onRefresh,
            child: isLoading && isEmpty
                ? Center(child: CircularProgressIndicator(color: AppColors.navy))
                : isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Text(emptyLabel,
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textMuted)),
                          ),
                        ],
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(20, 8, 20,
                            40 + MediaQuery.of(context).padding.bottom),
                        children: children,
                      ),
          ),
        ),
      ],
    );
  }
}

class _MuralCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? myRsvp;
  final ValueChanged<String> onRsvp;
  final VoidCallback onOpen;
  final VoidCallback? onRoteiro;
  final VoidCallback onAttendance;
  final bool showAttendance;

  const _MuralCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.myRsvp,
    required this.onRsvp,
    required this.onOpen,
    required this.onAttendance,
    required this.showAttendance,
    this.onRoteiro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.navy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.navy, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTextStyles.titleMedium
                                .copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (subtitle.isNotEmpty)
                          Text(subtitle,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                _RsvpChip(
                    label: 'Vou',
                    value: 'going',
                    selected: myRsvp == 'going',
                    color: AppColors.success,
                    onTap: () => onRsvp('going')),
                _RsvpChip(
                    label: 'Talvez',
                    value: 'maybe',
                    selected: myRsvp == 'maybe',
                    color: AppColors.warning,
                    onTap: () => onRsvp('maybe')),
                _RsvpChip(
                    label: 'Não',
                    value: 'declined',
                    selected: myRsvp == 'declined',
                    color: AppColors.error,
                    onTap: () => onRsvp('declined')),
                const Spacer(),
                if (onRoteiro != null)
                  IconButton(
                    icon: Icon(Icons.list_alt_outlined,
                        color: AppColors.textMuted, size: 20),
                    tooltip: 'Roteiro',
                    onPressed: onRoteiro,
                  ),
                if (showAttendance)
                  IconButton(
                    icon: Icon(Icons.how_to_reg_outlined,
                        color: AppColors.textMuted, size: 20),
                    tooltip: 'Lista de presença',
                    onPressed: onAttendance,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RsvpChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            border: Border.all(
                color: selected ? color : AppColors.divider,
                width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? color : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              )),
        ),
      ),
    );
  }
}

// ─── Menu (admin/dono) ───────────────────────────────────────────────────────

class _ClubMenu extends StatelessWidget {
  final ClubModel club;
  const _ClubMenu({required this.club});

  @override
  Widget build(BuildContext context) {
    if (!club.isActiveMember) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.navy),
      onSelected: (v) async {
        final vm = context.read<ClubViewModel>();
        if (v == 'leave') {
          final ok = await _confirm(
              context, 'Sair do clube', 'Deseja sair de "${club.name}"?');
          if (ok && context.mounted) {
            await vm.leave(club.id);
            if (context.mounted) context.pop();
          }
        } else if (v == 'delete') {
          final ok = await _confirm(context, 'Excluir clube',
              'Isso apaga o clube e seus dados. Continuar?');
          if (ok && context.mounted) {
            final done = await vm.deleteClub(club.id);
            if (done && context.mounted) context.pop();
          }
        }
      },
      itemBuilder: (_) => [
        if (!club.isOwner)
          const PopupMenuItem(value: 'leave', child: Text('Sair do clube')),
        if (club.isOwner)
          const PopupMenuItem(value: 'delete', child: Text('Excluir clube')),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmar', style: TextStyle(color: AppColors.error))),
      ],
    ),
  );
  return ok ?? false;
}
