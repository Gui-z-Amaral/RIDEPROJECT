import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/friend_tile.dart';
import '../../../shared/widgets/map_placeholder.dart';
import '../../../core/models/location_model.dart';
import '../../../core/services/mock_data.dart';
import '../../../core/utils/extensions.dart';
import '../viewmodels/ride_viewmodel.dart';
import '../../active_session/viewmodels/active_session_viewmodel.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  int _step = 0;
  final _meetCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<RideViewModel>().resetForm();
  }

  @override
  void dispose() {
    _meetCtrl.dispose();
    super.dispose();
  }

  void _nextStep() => setState(() => _step++);
  void _prevStep() {
    if (_step > 0) setState(() => _step--);
    else context.pop();
  }

  Future<void> _finish() async {
    final vm = context.read<RideViewModel>();
    final ride = await vm.saveRide();
    if (ride != null && mounted) {
      context.read<ActiveSessionViewModel>().startSession(id: ride.id, title: ride.title, isRide: true);
      context.showSnack('Rolê criado!');
      context.go('/session/waiting/${ride.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RideViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Rolê'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: _prevStep),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: List.generate(3, (i) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _step ? AppColors.teal : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: [_buildStep0(vm), _buildStep1(vm), _buildStep2(vm)][_step],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selecione quem vai participar', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        ...MockData.friends.map((u) => FriendTile(
              user: u,
              selected: vm.isParticipant(u),
              onTap: () => vm.toggleParticipant(u),
              actions: [],
            )),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(label: 'Próximo', icon: Icons.arrow_forward, iconTrailing: true, onPressed: _nextStep),
      ],
    );
  }

  Widget _buildStep1(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Onde é o ponto de encontro?', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        AppInput(
          controller: _meetCtrl,
          label: 'Ponto de encontro',
          hint: 'Endereço, praça ou ponto de referência',
          prefixIcon: Icons.location_on,
          onChanged: (v) => vm.setMeetingPoint(LocationModel(lat: -27.5954, lng: -48.5480, address: v)),
        ),
        const SizedBox(height: AppSpacing.lg),
        MapPlaceholder(
          height: 160,
          location: vm.meetingPoint,
          interactive: false,
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Próximo',
          icon: Icons.arrow_forward,
          iconTrailing: true,
          onPressed: _meetCtrl.text.isNotEmpty ? _nextStep : null,
        ),
      ],
    );
  }

  Widget _buildStep2(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirme os detalhes do rolê', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xl),

        // Summary card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppSpacing.radiusLg), border: Border.all(color: AppColors.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.error, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(vm.meetingPoint?.address ?? '', style: AppTextStyles.titleMedium)),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.people, color: AppColors.teal, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${vm.participants.length} participante${vm.participants.length != 1 ? 's' : ''}', style: AppTextStyles.bodyMedium),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.flash_on, color: AppColors.warning, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Rolê imediato', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Route to meeting point info
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.teal, size: 18),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text('A rota até o ponto de encontro será calculada pelo Google Maps ao iniciar.', style: TextStyle(color: AppColors.teal, fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        AppButton(label: 'Iniciar Rolê', icon: Icons.play_arrow, isLoading: vm.isSaving, onPressed: _finish),
      ],
    );
  }
}
