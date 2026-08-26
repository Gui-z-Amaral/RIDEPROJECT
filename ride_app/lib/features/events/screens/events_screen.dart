import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/supabase_event_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/event_viewmodel.dart';

/// Aba Eventos: próximos eventos perto de você (por UF) + busca.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<EventModel> _results = [];
  bool _searching = false;
  bool _isSearchMode = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadNearby);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNearby() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final uf = await GeocodingService.getStateUf(pos.latitude, pos.longitude);
      if (uf != null && mounted) {
        context.read<EventViewModel>().loadNearby(uf);
      }
    } catch (_) {}
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearchMode = false;
        _results = [];
      });
      return;
    }
    setState(() => _isSearchMode = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      try {
        final r = await SupabaseEventService.searchEvents(query);
        if (mounted) setState(() => _results = r);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventVm = context.watch<EventViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final list = _isSearchMode ? _results : eventVm.nearbyEvents;
    final loading = _isSearchMode
        ? _searching
        : (eventVm.isLoadingNearby && eventVm.nearbyEvents.isEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('Eventos',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isSearchMode
                    ? 'Resultados da busca'
                    : eventVm.loadedUf != null
                        ? 'Próximos eventos em ${eventVm.loadedUf}'
                        : 'Próximos eventos perto de você',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          // Busca
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Buscar evento por nome, cidade...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.inputFill,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Lista
          Expanded(
            child: RefreshIndicator(
              color: AppColors.navy,
              onRefresh: _loadNearby,
              child: loading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.navy))
                  : list.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                _isSearchMode
                                    ? 'Nenhum evento encontrado'
                                    : 'Nenhum evento perto de você ainda',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad + 24),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _EventListCard(event: list[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventListCard extends StatelessWidget {
  final EventModel event;
  const _EventListCard({required this.event});

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: SizedBox(
                width: 84,
                height: 84,
                child: (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: event.bannerUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(event.title,
                        style: AppTextStyles.titleMedium
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((event.city ?? '').isNotEmpty) event.city!,
                        _fmtDate(event.startsAt),
                      ].join(' · '),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${event.interestsCount} interessado${event.interestsCount == 1 ? '' : 's'}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child:
                  Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.inputFill,
        child: Icon(Icons.event, color: AppColors.navy.withOpacity(0.4), size: 30),
      );
}
