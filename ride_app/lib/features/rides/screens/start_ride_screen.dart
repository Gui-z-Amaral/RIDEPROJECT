import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/location_model.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../viewmodels/ride_viewmodel.dart';
import '../../../core/services/supabase_notification_service.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';

const _rideAccent = Color(0xFF9C6FE4);

class StartRideScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String placeName;
  final String placeAddress;

  const StartRideScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.placeName,
    required this.placeAddress,
  });

  @override
  State<StartRideScreen> createState() => _StartRideScreenState();
}

class _StartRideScreenState extends State<StartRideScreen> {
  final Set<String> _selectedFriendIds = {};
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SocialViewModel>().loadFriends());
  }

  String get _mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=${widget.lat},${widget.lng}';

  Future<void> _openInMaps() async {
    final uri = Uri.parse(_mapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _rideAccent,
            surface: AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _rideAccent,
            surface: AppColors.card,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);

    DateTime? scheduledAt;
    if (_selectedDate != null) {
      final time = _selectedTime ?? const TimeOfDay(hour: 8, minute: 0);
      scheduledAt = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        time.hour, time.minute,
      );
    }

    final rideVm = context.read<RideViewModel>();
    final friends = context.read<SocialViewModel>().friends;

    rideVm.resetForm();
    rideVm.setTitle(widget.placeName);
    rideVm.setMeetingPoint(LocationModel(
      lat: widget.lat,
      lng: widget.lng,
      address: widget.placeAddress,
      label: widget.placeName,
    ));
    rideVm.setScheduledAt(scheduledAt);

    for (final id in _selectedFriendIds) {
      final friend = friends.where((f) => f.id == id).firstOrNull;
      if (friend != null) rideVm.toggleParticipant(friend);
    }

    final ride = await rideVm.saveRide();
    if (!mounted) return;

    if (ride != null && _selectedFriendIds.isNotEmpty) {
      final creatorName =
          context.read<AuthViewModel>().user?.name ?? 'Alguém';
      try {
        await SupabaseNotificationService.sendInviteNotifications(
          userIds: _selectedFriendIds.toList(),
          type: 'ride_invite',
          title: 'Convite para rolê',
          body: '$creatorName te convidou para um rolê em "${widget.placeName}"',
          data: {
            'rideId': ride.id,
            'place': widget.placeName,
            'address': widget.placeAddress,
            'lat': widget.lat,
            'lng': widget.lng,
          },
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ride != null) {
      context.go('/rides');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rolê em "${widget.placeName}" criado!'),
          backgroundColor: _rideAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao criar o rolê. Tente novamente.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = context.watch<SocialViewModel>().friends;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Rolê'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Card do ponto de encontro ─────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      border: Border.all(color: _rideAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: _rideAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(Icons.location_on, color: _rideAccent, size: 26),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ponto de encontro',
                                  style: AppTextStyles.labelSmall.copyWith(color: _rideAccent)),
                              Text(widget.placeName, style: AppTextStyles.titleLarge,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text(widget.placeAddress,
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Data e hora ───────────────────────────────────
                  Text('Data e hora', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerBtn(
                          icon: Icons.calendar_today_outlined,
                          label: _selectedDate == null
                              ? 'Escolher data'
                              : '${_selectedDate!.day.toString().padLeft(2,'0')}/${_selectedDate!.month.toString().padLeft(2,'0')}/${_selectedDate!.year}',
                          hasValue: _selectedDate != null,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _PickerBtn(
                          icon: Icons.access_time,
                          label: _selectedTime == null
                              ? 'Escolher hora'
                              : '${_selectedTime!.hour.toString().padLeft(2,'0')}:${_selectedTime!.minute.toString().padLeft(2,'0')}',
                          hasValue: _selectedTime != null,
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Convidar participantes ────────────────────────
                  Row(
                    children: [
                      Text('Convidar participantes', style: AppTextStyles.titleMedium),
                      const Spacer(),
                      if (_selectedFriendIds.isNotEmpty)
                        Text('${_selectedFriendIds.length} selecionado(s)',
                            style: AppTextStyles.labelSmall.copyWith(color: _rideAccent)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (friends.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.people_outline, color: AppColors.textMuted),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Nenhum amigo ainda',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  else
                    ...friends.map((friend) => _FriendTile(
                      friend: friend,
                      selected: _selectedFriendIds.contains(friend.id),
                      onToggle: () => setState(() {
                        if (_selectedFriendIds.contains(friend.id)) {
                          _selectedFriendIds.remove(friend.id);
                        } else {
                          _selectedFriendIds.add(friend.id);
                        }
                      }),
                    )),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Link Google Maps ──────────────────────────────
                  Text('Ver no Google Maps', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _MapsLinkBtn(
                    placeName: widget.placeName,
                    onTap: _openInMaps,
                  ),

                  SizedBox(height: bottomPad + 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg, right: AppSpacing.lg,
          bottom: bottomPad + AppSpacing.md,
          top: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: ElevatedButton(
          onPressed: _saving ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _rideAccent,
            foregroundColor: AppColors.deepNavy,
            disabledBackgroundColor: _rideAccent.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.deepNavy),
                )
              : Text(
                  'Confirmar Rolê',
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.deepNavy, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PickerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  const _PickerBtn({
    required this.icon, required this.label,
    required this.hasValue, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: hasValue ? _rideAccent.withOpacity(0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: hasValue ? _rideAccent.withOpacity(0.4) : AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: hasValue ? _rideAccent : AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: hasValue ? _rideAccent : AppColors.textMuted),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final UserModel friend;
  final bool selected;
  final VoidCallback onToggle;

  const _FriendTile({required this.friend, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? _rideAccent.withOpacity(0.08) : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: selected ? _rideAccent.withOpacity(0.4) : AppColors.divider),
        ),
        child: Row(
          children: [
            AppAvatar(name: friend.name, imageUrl: friend.avatarUrl, size: 40,
                showOnline: true, isOnline: friend.isOnline),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: AppTextStyles.titleMedium),
                  if (friend.motoModel != null)
                    Text(friend.motoModel!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: selected ? _rideAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? _rideAccent : AppColors.divider, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: AppColors.deepNavy)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapsLinkBtn extends StatelessWidget {
  final String placeName;
  final VoidCallback onTap;

  const _MapsLinkBtn({required this.placeName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.map, color: Color(0xFF4285F4), size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Abrir no Google Maps', style: AppTextStyles.titleMedium),
                  Text(placeName,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
