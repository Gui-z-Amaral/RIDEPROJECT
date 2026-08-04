import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/supabase_social_service.dart';
import '../../../core/services/supabase_event_service.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../rides/viewmodels/ride_viewmodel.dart';
import '../../trips/viewmodels/trip_viewmodel.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  // Token incremental para descartar respostas obsoletas (ex: o usuário
  // continuou digitando antes da request anterior terminar).
  int _searchToken = 0;

  String _query = '';
  List<UserModel> _users = [];
  List<PlaceRecommendation> _places = [];
  List<EventModel> _events = [];
  bool _isSearchingUsers = false;
  bool _isSearchingPlaces = false;
  bool _isSearchingEvents = false;

  // Localização do dispositivo, usada para ranquear lugares por proximidade.
  // Resultado fica null se a permissão for negada — a busca ainda funciona,
  // só não prioriza os mais próximos.
  double? _deviceLat;
  double? _deviceLng;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final tripVm = context.read<TripViewModel>();
      final rideVm = context.read<RideViewModel>();
      if (tripVm.trips.isEmpty) tripVm.loadTrips();
      if (rideVm.rides.isEmpty) rideVm.loadRides();
    });
    _fetchDeviceLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _fetchDeviceLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      setState(() {
        _deviceLat = pos.latitude;
        _deviceLng = pos.longitude;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final trimmed = v.trim();
    setState(() => _query = trimmed);
    _debounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _users = [];
        _places = [];
        _events = [];
        _isSearchingUsers = false;
        _isSearchingPlaces = false;
        _isSearchingEvents = false;
      });
      return;
    }
    setState(() {
      _isSearchingUsers = true;
      _isSearchingPlaces = true;
      _isSearchingEvents = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _runRemoteSearches);
  }

  /// Dispara busca de usuários (Supabase) e lugares (Google Places) em
  /// paralelo. Cada uma usa o mesmo `_searchToken` para descartar respostas
  /// obsoletas se o usuário continuar digitando.
  Future<void> _runRemoteSearches() async {
    final q = _query;
    if (q.isEmpty) return;
    final myToken = ++_searchToken;

    // Usuários
    SupabaseSocialService.searchUsers(q).then((res) {
      if (!mounted || myToken != _searchToken) return;
      setState(() {
        _users = res;
        _isSearchingUsers = false;
      });
    }).catchError((_) {
      if (!mounted || myToken != _searchToken) return;
      setState(() => _isSearchingUsers = false);
    });

    // Lugares (Google Places)
    PlacesService.searchPlaces(
      query: q,
      lat: _deviceLat,
      lng: _deviceLng,
    ).then((res) {
      if (!mounted || myToken != _searchToken) return;
      setState(() {
        _places = res;
        _isSearchingPlaces = false;
      });
    }).catchError((_) {
      if (!mounted || myToken != _searchToken) return;
      setState(() => _isSearchingPlaces = false);
    });

    // Eventos (Supabase)
    SupabaseEventService.searchEvents(q).then((res) {
      if (!mounted || myToken != _searchToken) return;
      setState(() {
        _events = res;
        _isSearchingEvents = false;
      });
    }).catchError((_) {
      if (!mounted || myToken != _searchToken) return;
      setState(() => _isSearchingEvents = false);
    });
  }

  /// Abre o lugar direto no Google Maps. (Criar viagem/rolê é feito pelos
  /// fluxos próprios, não pela busca.)
  Future<void> _openPlaceInMaps(PlaceRecommendation place) async {
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripVm = context.watch<TripViewModel>();
    final rideVm = context.watch<RideViewModel>();
    final q = _query.toLowerCase();

    final trips = q.isEmpty
        ? <TripModel>[]
        : tripVm.trips.where((t) {
            return t.title.toLowerCase().contains(q) ||
                (t.destination.address?.toLowerCase().contains(q) ?? false) ||
                (t.origin.address?.toLowerCase().contains(q) ?? false);
          }).toList();

    final rides = q.isEmpty
        ? <RideModel>[]
        : rideVm.rides.where((r) {
            return r.title.toLowerCase().contains(q) ||
                (r.meetingPoint.address?.toLowerCase().contains(q) ?? false);
          }).toList();

    final isLoadingAny =
        _isSearchingUsers || _isSearchingPlaces || _isSearchingEvents;
    final hasAnyResult = _users.isNotEmpty ||
        _places.isNotEmpty ||
        _events.isNotEmpty ||
        trips.isNotEmpty ||
        rides.isNotEmpty;
    final showEmptyResults =
        _query.isNotEmpty && !isLoadingAny && !hasAnyResult;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          focusNode: _focusNode,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Pesquise lugares, agendamentos ou pessoas',
            hintStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textMuted),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: AppColors.textMuted),
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? const _HintState(
              icon: Icons.search,
              message: 'Comece a digitar para pesquisar',
              hint: 'Busque por lugares, amigos, viagens ou rolês',
            )
          : showEmptyResults
              ? _HintState(
                  icon: Icons.search_off,
                  message: 'Nenhum resultado para "$_query"',
                  hint: 'Tente outro termo',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md + MediaQuery.of(context).padding.bottom),
                  children: [
                    // ── EVENTOS (Supabase) ───────────────────────────────
                    if (_isSearchingEvents && _events.isEmpty) ...[
                      const _SectionHeader('EVENTOS'),
                      const _LoadingRow(),
                      const SizedBox(height: AppSpacing.md),
                    ] else if (_events.isNotEmpty) ...[
                      const _SectionHeader('EVENTOS'),
                      ..._events.map((e) => _EventTile(event: e)),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── LUGARES (Google Places) ──────────────────────────
                    if (_isSearchingPlaces && _places.isEmpty) ...[
                      const _SectionHeader('LUGARES'),
                      const _LoadingRow(),
                      const SizedBox(height: AppSpacing.md),
                    ] else if (_places.isNotEmpty) ...[
                      const _SectionHeader('LUGARES'),
                      ..._places
                          .map((p) => _PlaceTile(
                                place: p,
                                onTap: () => _openPlaceInMaps(p),
                              )),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── PESSOAS ───────────────────────────────────────────
                    if (_isSearchingUsers && _users.isEmpty) ...[
                      const _SectionHeader('PESSOAS'),
                      const _LoadingRow(),
                      const SizedBox(height: AppSpacing.md),
                    ] else if (_users.isNotEmpty) ...[
                      const _SectionHeader('PESSOAS'),
                      ..._users.map((u) => _UserTile(user: u)),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── VIAGENS (locais carregados) ──────────────────────
                    if (trips.isNotEmpty) ...[
                      const _SectionHeader('VIAGENS'),
                      ...trips.map((t) => _TripTile(trip: t)),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // ── ROLÊS (locais carregados) ────────────────────────
                    if (rides.isNotEmpty) ...[
                      const _SectionHeader('ROLÊS'),
                      ...rides.map((r) => _RideTile(ride: r)),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.navy),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final PlaceRecommendation place;
  final VoidCallback onTap;
  const _PlaceTile({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Foto do lugar (Google Places Photo) ou ícone fallback
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: SizedBox(
                width: 56,
                height: 56,
                child: place.photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: place.photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.inputFill,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.inputFill,
                          child: Icon(Icons.place,
                              color: AppColors.textMuted, size: 24),
                        ),
                      )
                    : Container(
                        color: AppColors.inputFill,
                        child: Icon(Icons.place,
                            color: AppColors.textMuted, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (place.vicinity.isNotEmpty)
                    Text(
                      place.vicinity,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (place.rating != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(
                          place.rating!.toStringAsFixed(1),
                          style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.w700),
                        ),
                        if (place.distanceKm > 0) ...[
                          const SizedBox(width: 8),
                          Text('• ${place.distanceLabel}',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ] else if (place.distanceKm > 0) ...[
                    const SizedBox(height: 2),
                    Text(place.distanceLabel,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/profile/${user.id}', extra: user),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            AppAvatar(
              name: user.name,
              imageUrl: user.avatarUrl,
              size: 40,
              showOnline: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: AppTextStyles.titleMedium),
                  if (user.username.isNotEmpty)
                    Text('@${user.username}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final TripModel trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dest = trip.destination.address ?? '';
    return InkWell(
      onTap: () => context.push('/trips/${trip.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.map_outlined,
                  color: AppColors.teal, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (dest.isNotEmpty)
                    Text(dest,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventModel event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final subtitle = [
      dateLabel,
      if ((event.locationLabel ?? event.city ?? '').isNotEmpty)
        (event.locationLabel ?? event.city),
    ].whereType<String>().join(' · ');

    return InkWell(
      onTap: () => context.push('/events/${event.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: SizedBox(
                width: 56,
                height: 56,
                child: event.bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: event.bannerUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.navy.withOpacity(0.1),
                          child: Icon(Icons.event, color: AppColors.navy),
                        ),
                      )
                    : Container(
                        color: AppColors.navy.withOpacity(0.1),
                        child: Icon(Icons.event, color: AppColors.navy),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      Icon(Icons.people_outline,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text('${event.interestsCount}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  final RideModel ride;
  const _RideTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    final addr = ride.meetingPoint.address ?? '';
    return InkWell(
      onTap: () => context.push('/rides/${ride.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF9C6FE4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.groups_outlined,
                  color: Color(0xFF9C6FE4), size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ride.title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (addr.isNotEmpty)
                    Text(addr,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _HintState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  const _HintState({
    required this.icon,
    required this.message,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(hint,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
