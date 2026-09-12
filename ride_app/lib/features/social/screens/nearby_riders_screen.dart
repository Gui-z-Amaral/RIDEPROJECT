import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_rider_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../profile/viewmodels/profile_viewmodel.dart';

/// Descoberta de riders próximos: lista do mais perto pro mais longe.
class NearbyRidersScreen extends StatefulWidget {
  const NearbyRidersScreen({super.key});

  @override
  State<NearbyRidersScreen> createState() => _NearbyRidersScreenState();
}

class _NearbyRidersScreenState extends State<NearbyRidersScreen> {
  bool _loading = true;
  String? _error;
  List<NearbyRider> _riders = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _loading = false;
          _error = 'Ative a localização para ver riders perto de você.';
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced,
          timeLimit: Duration(seconds: 12),
        ),
      );

      // Atualiza a própria localização só se você aparece na descoberta.
      final discoverable =
          context.read<ProfileViewModel>().user?.discoverable ?? true;
      if (discoverable) {
        await SupabaseRiderService.updateMyLocation(
            pos.latitude, pos.longitude);
      }

      final riders =
          await SupabaseRiderService.getNearby(pos.latitude, pos.longitude);
      if (mounted) setState(() => _riders = riders);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar os riders.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openProfile(NearbyRider r) {
    // Passa um UserModel mínimo; a tela de perfil recarrega o resto por id.
    final user = UserModel(
      id: r.id,
      name: r.name,
      username: r.username,
      avatarUrl: r.avatarUrl,
      motoModel: r.motoModel,
      tripStyle: r.tripStyle,
    );
    context.push('/profile/${r.id}', extra: user);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final discoverable =
        context.watch<ProfileViewModel>().user?.discoverable ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text('Riders próximos',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.navy),
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: _load,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: AppColors.navy))
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 24),
                children: [
                  if (!discoverable)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Você está oculto na descoberta. Ative em Configurações para outros te encontrarem.',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textMuted)),
                      ),
                    )
                  else if (_riders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.explore_off_outlined,
                                size: 48, color: AppColors.navy.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text('Nenhum rider por perto ainda',
                                style: AppTextStyles.titleMedium
                                    .copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._riders.map((r) => _RiderTile(
                          rider: r,
                          onTap: () => _openProfile(r),
                        )),
                ],
              ),
      ),
    );
  }
}

class _RiderTile extends StatelessWidget {
  final NearbyRider rider;
  final VoidCallback onTap;
  const _RiderTile({required this.rider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.navy.withOpacity(0.1),
              backgroundImage:
                  (rider.avatarUrl != null && rider.avatarUrl!.isNotEmpty)
                      ? NetworkImage(rider.avatarUrl!)
                      : null,
              child: (rider.avatarUrl == null || rider.avatarUrl!.isEmpty)
                  ? Text(
                      rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                      style: AppTextStyles.titleLarge
                          .copyWith(color: AppColors.navy))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rider.name,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (rider.username.isNotEmpty)
                    Text('@${rider.username}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.near_me, size: 16, color: AppColors.teal),
                const SizedBox(height: 2),
                Text(rider.distanceLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.navy, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
