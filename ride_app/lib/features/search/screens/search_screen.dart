import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/services/supabase_social_service.dart';
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

  String _query = '';
  List<UserModel> _users = [];
  bool _isSearchingUsers = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
        _isSearchingUsers = false;
      });
      return;
    }
    setState(() => _isSearchingUsers = true);
    _debounce = Timer(const Duration(milliseconds: 300), _runUserSearch);
  }

  Future<void> _runUserSearch() async {
    final q = _query;
    if (q.isEmpty) return;
    try {
      final res = await SupabaseSocialService.searchUsers(q);
      if (!mounted || q != _query) return;
      setState(() {
        _users = res;
        _isSearchingUsers = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearchingUsers = false);
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

    final hasAnyResult =
        _users.isNotEmpty || trips.isNotEmpty || rides.isNotEmpty;
    final showEmptyResults = _query.isNotEmpty &&
        !_isSearchingUsers &&
        !hasAnyResult;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
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
              icon: const Icon(Icons.close, color: AppColors.textMuted),
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
              hint: 'Busque por amigos, viagens ou rolês',
            )
          : showEmptyResults
              ? _HintState(
                  icon: Icons.search_off,
                  message: 'Nenhum resultado para "$_query"',
                  hint: 'Tente outro termo',
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  children: [
                    if (_isSearchingUsers && _users.isEmpty) ...[
                      const _SectionHeader('PESSOAS'),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.navy),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ] else if (_users.isNotEmpty) ...[
                      const _SectionHeader('PESSOAS'),
                      ..._users.map((u) => _UserTile(user: u)),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (trips.isNotEmpty) ...[
                      const _SectionHeader('VIAGENS'),
                      ...trips.map((t) => _TripTile(trip: t)),
                      const SizedBox(height: AppSpacing.md),
                    ],
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
