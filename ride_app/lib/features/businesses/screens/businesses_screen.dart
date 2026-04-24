import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/places_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

class BusinessesScreen extends StatefulWidget {
  const BusinessesScreen({super.key});

  @override
  State<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends State<BusinessesScreen> {
  BusinessCategory _selected = BusinessCategory.gasStation;
  double? _lat;
  double? _lng;
  bool _loadingLocation = true;
  bool _loadingResults = false;
  String? _locationError;
  List<PlaceRecommendation> _results = [];
  // Token que invalida respostas pendentes quando o usuário troca de categoria
  // antes da request anterior terminar (evita race: último que começa ganha).
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _loadingLocation = false;
            _locationError = 'Ative a localização para encontrar empresas perto de você.';
          });
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _loadingLocation = false;
      });
      _loadResults();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Não foi possível obter sua localização.';
        });
      }
    }
  }

  Future<void> _loadResults() async {
    if (_lat == null || _lng == null) return;
    final myToken = ++_loadToken;
    final requestedCategory = _selected;
    setState(() => _loadingResults = true);
    try {
      final res = await PlacesService.getTrustedBusinesses(
        lat: _lat!,
        lng: _lng!,
        category: requestedCategory,
      );
      // Se o usuário trocou de categoria no meio, descarta o resultado
      if (!mounted || myToken != _loadToken) return;
      setState(() {
        _results = res;
        _loadingResults = false;
      });
    } catch (_) {
      if (!mounted || myToken != _loadToken) return;
      setState(() {
        _results = [];
        _loadingResults = false;
      });
    }
  }

  void _selectCategory(BusinessCategory c) {
    if (c == _selected) return;
    setState(() {
      _selected = c;
      _results = [];
    });
    _loadResults();
  }

  Future<void> _openInMaps(PlaceRecommendation place) async {
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Empresas confiáveis',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Avaliações do Google — mostramos somente empresas com nota ≥ 3.5',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          ),

          // ── Categorias ──────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: BusinessCategory.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final c = BusinessCategory.values[i];
                final selected = c == _selected;
                return _CategoryChip(
                  label: c.label,
                  icon: _iconFor(c),
                  selected: selected,
                  onTap: () => _selectCategory(c),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingLocation) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_locationError != null) {
      return _ErrorState(
        message: _locationError!,
        onRetry: _fetchLocation,
      );
    }
    if (_loadingResults && _results.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_results.isEmpty) {
      return _ErrorState(
        message:
            'Nenhuma empresa confiável encontrada nesta categoria perto de você.',
        onRetry: _loadResults,
        icon: Icons.search_off,
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: _loadResults,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl + MediaQuery.of(context).padding.bottom),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => _BusinessCard(
          place: _results[i],
          onTap: () => _openInMaps(_results[i]),
        ),
      ),
    );
  }

  IconData _iconFor(BusinessCategory c) {
    switch (c) {
      case BusinessCategory.gasStation:
        return Icons.local_gas_station;
      case BusinessCategory.mechanic:
        return Icons.build;
      case BusinessCategory.tireShop:
        return Icons.tire_repair;
      case BusinessCategory.carWash:
        return Icons.local_car_wash;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.navy),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final PlaceRecommendation place;
  final VoidCallback onTap;
  const _BusinessCard({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = place.photoUrl.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Foto ─────────────────────────────────────────────
            SizedBox(
              height: 140,
              child: hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: place.photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.inputFill,
                        child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.navy)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.inputFill,
                        child: const Icon(Icons.store,
                            color: AppColors.textMuted, size: 42),
                      ),
                    )
                  : Container(
                      color: AppColors.inputFill,
                      child: const Icon(Icons.store,
                          color: AppColors.textMuted, size: 42),
                    ),
            ),

            // ── Conteúdo ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _OpenBadge(isOpen: place.isOpenNow),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _RatingRow(
                    rating: place.rating,
                    reviews: place.userRatingsTotal,
                  ),
                  if (place.vicinity.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.vicinity,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          place.distanceLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onTap,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: Text('Ver no Google Maps',
                              style: AppTextStyles.labelMedium
                                  .copyWith(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: const BorderSide(color: AppColors.navy),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double? rating;
  final int? reviews;
  const _RatingRow({this.rating, this.reviews});

  @override
  Widget build(BuildContext context) {
    if (rating == null) {
      return Text('Sem avaliação',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted));
    }
    return Row(
      children: [
        const Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          rating!.toStringAsFixed(1),
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 4),
        if (reviews != null)
          Text(
            '(${_fmtCount(reviews!)})',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
      ],
    );
  }

  static String _fmtCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _OpenBadge extends StatelessWidget {
  final bool isOpen;
  const _OpenBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color),
      ),
      child: Text(
        isOpen ? 'Aberto' : 'Fechado',
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.icon = Icons.location_off_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
