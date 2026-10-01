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
import '../../../shared/widgets/rsvp_bar.dart';
import '../../../core/models/trip_model.dart';
import '../../../shared/widgets/formatted_text.dart';

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
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
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
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
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
    final hasBanner = club.bannerUrl != null && club.bannerUrl!.isNotEmpty;
    final hasLogo = club.avatarUrl != null && club.avatarUrl!.isNotEmpty;
    return SizedBox(
      height: 158,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner ao fundo (ou gradiente navy quando não há banner).
          if (hasBanner)
            Image.network(club.bannerUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _bannerFallback())
          else
            _bannerFallback(),
          // Escurece o rodapé pra leitura do nome/logo por cima.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          // Logo + nome por cima do banner (no rodapé).
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.navy,
                    backgroundImage:
                        hasLogo ? NetworkImage(club.avatarUrl!) : null,
                    child: hasLogo
                        ? null
                        : const Icon(Icons.shield_moon_outlined,
                            color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (club.location.isNotEmpty) club.location,
                          '${club.membersCount} ${club.membersCount == 1 ? 'membro' : 'membros'}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white70,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerFallback() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.mediumBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

// ─── Aba Sobre ───────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final ClubModel club;
  const _AboutTab({required this.club});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    final managers = vm.managers;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 40 + MediaQuery.of(context).padding.bottom),
      children: [
        // ── Sobre ───────────────────────────────────────────
        Text('Sobre',
            style: AppTextStyles.titleMedium
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        FormattedText(
          (club.description ?? '').isNotEmpty
              ? club.description!
              : 'Este motoclube ainda não tem uma descrição.',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),

        // ── Gerentes ────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gerentes',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w800)),
            GestureDetector(
              onTap: () => DefaultTabController.of(context).animateTo(1),
              child: Text('Ver todos',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.navy)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (managers.isEmpty)
          Text('Nenhum gerente ainda',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted))
        else
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children:
                managers.map((m) => _ManagerChip(member: m)).toList(),
          ),

        // ── Configurações (dono/gerente) ────────────────────
        if (club.isAdmin) ...[
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/clubs/${club.id}/settings'),
              icon: Icon(Icons.settings_outlined, color: AppColors.navy),
              label: Text('CONFIGURAÇÕES DO MOTOCLUBE',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.navy, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.navy, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],

        // ── Sair (membro não-dono) ──────────────────────────
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

class _ManagerChip extends StatelessWidget {
  final ClubMemberModel member;
  const _ManagerChip({required this.member});

  @override
  Widget build(BuildContext context) {
    final u = member.user;
    final name = (u?.name ?? 'Gerente').split(' ').first;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.navy.withOpacity(0.1),
            backgroundImage: (u?.avatarUrl != null && u!.avatarUrl!.isNotEmpty)
                ? NetworkImage(u.avatarUrl!)
                : null,
            child: (u?.avatarUrl == null || (u?.avatarUrl?.isEmpty ?? true))
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.navy))
                : null,
          ),
          const SizedBox(height: 6),
          Text(name,
              style: AppTextStyles.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          Text(member.isOwner ? 'Dono' : 'Gerente',
              style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.navy,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
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

    // Não há mais cadeado por clube: desde a migration 034 a visibilidade é de
    // cada evento e de cada viagem. Quem não é membro vê a lista normalmente e
    // recebe só o que for público — quem filtra é a RLS, no banco, não a tela.
    // Manter o cadeado aqui deixaria a aba trancada para sempre, já que o
    // interruptor do clube saiu da interface.

    // Une eventos e viagens numa lista só, ordenada por data (próximos
    // primeiro). Concluídas saem daqui e vão para o histórico, no fim.
    final items = <_Activity>[
      ...vm.clubEvents.map((e) => _Activity(
            date: e.startsAt,
            done: e.isCompleted,
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
              showRsvp: club.isActiveMember,
              isCompleted: e.isCompleted,
              // Só gerente e dono concluem. A RLS garante o mesmo no banco —
              // isto aqui é só para não oferecer um botão que vai recusar.
              onToggleCompleted: club.isAdmin
                  ? () => _concluir(context, e.id, e.title, e.isCompleted)
                  : null,
            ),
          )),
      ...vm.clubTrips.map((t) {
        final city = t.destination.address?.split(',').first.trim() ??
            t.destination.label ??
            '';
        return _Activity(
          date: t.scheduledAt,
          // Viagem já nasce com status desde a 001 — reaproveitado aqui em vez
          // de inventar uma segunda forma de dizer a mesma coisa.
          done: t.status == TripStatus.completed,
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
            showRsvp: club.isActiveMember,
            isCompleted: t.status == TripStatus.completed,
          ),
        );
      }),
    ];
    // Ordena por data; itens sem data vão para o fim.
    int porData(_Activity a, _Activity b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    }

    final ativas = items.where((a) => !a.done).toList()..sort(porData);
    // Histórico ao contrário: a última que aconteceu vem primeiro.
    final concluidas = items.where((a) => a.done).toList()
      ..sort((a, b) => porData(b, a));

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
      children: [
        ...ativas.map((a) => a.card),
        if (concluidas.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 12),
            child: Row(
              children: [
                Text('Concluídas',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Text('${concluidas.length}',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: AppColors.divider, height: 1)),
              ],
            ),
          ),
          ...concluidas.map((a) => a.card),
        ],
      ],
    );
  }
}

class _Activity {
  final DateTime? date;
  final Widget card;

  /// Já aconteceu: evento com `completed_at` (migration 041) ou viagem com
  /// `status = completed`. Separa o histórico do que ainda vem.
  final bool done;
  const _Activity({required this.date, required this.card, this.done = false});
}

/// Conclui ou reabre um evento do clube, avisando se o servidor recusar.
Future<void> _concluir(
    BuildContext context, String eventId, String titulo, bool concluido) async {
  final vm = context.read<ClubViewModel>();
  final ok = await vm.setEventCompleted(eventId, !concluido);
  if (!context.mounted) return;
  if (ok) {
    context.showSnack(concluido
        ? '"$titulo" voltou para as ativas.'
        : '"$titulo" foi para o histórico.');
  } else {
    context.showSnack('Não foi possível alterar o evento.', isError: true);
  }
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
  final bool showRsvp;

  /// Atividade encerrada — vai para a seção de histórico e fica atenuada.
  final bool isCompleted;

  /// Concluir/reabrir. `null` esconde a ação: só gerente e dono a têm, e
  /// viagem não tem (ela já se conclui pelo próprio fluxo de rolê).
  final Future<void> Function()? onToggleCompleted;

  const _MuralCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.myRsvp,
    required this.onRsvp,
    required this.onOpen,
    required this.onAttendance,
    required this.showAttendance,
    this.showRsvp = true,
    this.onRoteiro,
    this.isCompleted = false,
    this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // Concluída fica atenuada: continua legível e clicável, mas não disputa
    // atenção com o que ainda vai acontecer.
    return Opacity(
      opacity: isCompleted ? 0.65 : 1,
      child: Container(
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
          if (showRsvp || showAttendance || onRoteiro != null ||
              onToggleCompleted != null) ...[
          Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                // Presença some depois de concluída: responder "vou" a algo
                // que já aconteceu não quer dizer nada.
                if (showRsvp && !isCompleted)
                  RsvpBar(myRsvp: myRsvp, onRsvp: onRsvp),
                if (isCompleted)
                  Text('Concluída',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textMuted)),
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
                if (onToggleCompleted != null)
                  IconButton(
                    icon: Icon(
                        isCompleted
                            ? Icons.replay_outlined
                            : Icons.task_alt_outlined,
                        color: AppColors.textMuted,
                        size: 20),
                    tooltip: isCompleted ? 'Reabrir' : 'Marcar como concluída',
                    onPressed: () => onToggleCompleted!(),
                  ),
              ],
            ),
          ),
          ],
        ],
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
