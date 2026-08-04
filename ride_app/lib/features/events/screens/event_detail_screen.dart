import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/event_model.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/event_viewmodel.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<EventViewModel>().loadDetail(widget.eventId));
  }

  static const _months = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  String _fmtDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.day} de ${_months[d.month]} de ${d.year} · $hh:$mi';
  }

  Future<void> _openMaps(EventModel e) async {
    final uri = Uri.parse(e.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDelete(EventModel e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir evento'),
        content: Text('Deseja excluir "${e.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final ok = await context.read<EventViewModel>().deleteEvent(e.id);
      if (!mounted) return;
      if (ok) {
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível excluir.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EventViewModel>();
    final e = vm.selected;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = e != null && e.creatorId == myId;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: vm.isLoadingDetail || e == null
          ? _loadingOrMissing(vm)
          : CustomScrollView(
              slivers: [
                // ── Banner com app bar ───────────────────────────
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: AppColors.navy,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    if (isOwner) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: Colors.white),
                        onPressed: () => context.push('/events/${e.id}/edit'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        onPressed: () => _confirmDelete(e),
                      ),
                    ],
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (e.bannerUrl != null)
                          CachedNetworkImage(
                            imageUrl: e.bannerUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Container(color: AppColors.navy),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.navy, AppColors.mediumBlue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.event,
                                  color: Colors.white24, size: 64),
                            ),
                          ),
                        // Escurece o rodapé pra leitura do contador
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 80,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black54],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Contador de interesse no canto do banner
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  '${e.interestsCount} interessado${e.interestsCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(e.title,
                            style: AppTextStyles.headlineLarge.copyWith(
                                fontWeight: FontWeight.w800, fontSize: 22)),
                        if (e.creator?.displayName.isNotEmpty ?? false) ...[
                          const SizedBox(height: 4),
                          Text('por ${e.creator!.displayName}',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                        const SizedBox(height: 20),

                        // Data
                        _InfoRow(
                          icon: Icons.calendar_today,
                          title: _fmtDateTime(e.startsAt),
                          subtitle: e.endsAt != null
                              ? 'até ${_fmtDateTime(e.endsAt!)}'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Local
                        if (e.locationLabel != null || e.address != null)
                          GestureDetector(
                            onTap: () => _openMaps(e),
                            child: _InfoRow(
                              icon: Icons.location_on_outlined,
                              title: e.locationLabel?.isNotEmpty == true
                                  ? e.locationLabel!
                                  : (e.address ?? 'Local'),
                              subtitle: [
                                if ((e.address ?? '').isNotEmpty) e.address,
                                if (e.stateUf != null) e.stateUf,
                              ].whereType<String>().join(' · '),
                              trailing: 'Ver no mapa →',
                            ),
                          ),

                        // Descrição
                        if ((e.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('Sobre',
                              style: AppTextStyles.headlineMedium
                                  .copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(e.description!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                        ],

                        // Programação
                        if (e.schedule.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('Programação',
                              style: AppTextStyles.headlineMedium
                                  .copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          ...e.schedule.map((s) => _ScheduleRow(item: s)),
                        ],

                        // Participantes extras
                        if (e.participants.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('Participantes',
                              style: AppTextStyles.headlineMedium
                                  .copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: e.participants
                                .map((p) => GestureDetector(
                                      onTap: () => context.push(
                                          '/profile/${p.id}',
                                          extra: p),
                                      child: SizedBox(
                                        width: 64,
                                        child: Column(
                                          children: [
                                            AppAvatar(
                                                name: p.name,
                                                imageUrl: p.avatarUrl,
                                                size: 52),
                                            const SizedBox(height: 4),
                                            Text(p.name.split(' ').first,
                                                style: AppTextStyles.bodySmall,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],

                        // Patrocinadores
                        if (e.sponsors.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text('Patrocinadores',
                              style: AppTextStyles.headlineMedium
                                  .copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: e.sponsors
                                .map((s) => _SponsorBadge(sponsor: s))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
      // ── Botão de interesse fixo no rodapé ────────────────────
      bottomSheet: (vm.isLoadingDetail || e == null)
          ? null
          : _InterestBar(
              event: e,
              onTap: () => context.read<EventViewModel>().toggleInterest(e.id),
            ),
    );
  }

  Widget _loadingOrMissing(EventViewModel vm) {
    if (vm.isLoadingDetail) {
      return Center(child: CircularProgressIndicator(color: AppColors.navy));
    }
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.navy),
              onPressed: () => context.pop(),
            ),
          ),
          const Expanded(
            child: Center(child: Text('Evento não encontrado')),
          ),
        ],
      ),
    );
  }
}

// ─── Barra de interesse ─────────────────────────────────────────────────────────

class _InterestBar extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  const _InterestBar({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final interested = event.isInterested;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: interested ? AppColors.teal : AppColors.navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          icon: Icon(
              interested ? Icons.check_circle : Icons.star_border, size: 20),
          label: Text(
            interested ? 'TENHO INTERESSE ✓' : 'TENHO INTERESSE',
            style: AppTextStyles.labelLarge,
          ),
        ),
      ),
    );
  }
}

// ─── Linhas de info ──────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.navy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.navy, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTextStyles.titleSmall
                      .copyWith(fontWeight: FontWeight.w700)),
              if ((subtitle ?? '').isNotEmpty)
                Text(subtitle!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted)),
              if (trailing != null) ...[
                const SizedBox(height: 2),
                Text(trailing!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.navy)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SponsorBadge extends StatelessWidget {
  final EventSponsor sponsor;
  const _SponsorBadge({required this.sponsor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sponsor.logoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(sponsor.logoUrl!,
                  width: 28, height: 28, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.business, size: 20, color: AppColors.textMuted)),
            ),
            const SizedBox(width: 8),
          ] else
            Icon(Icons.business, size: 20, color: AppColors.navy),
          if (sponsor.logoUrl == null) const SizedBox(width: 8),
          Text(sponsor.name,
              style: AppTextStyles.titleSmall
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final EventScheduleItem item;
  const _ScheduleRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              item.timeLabel?.isNotEmpty == true ? item.timeLabel! : '•',
              style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.navy, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                if ((item.description ?? '').isNotEmpty)
                  Text(item.description!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
