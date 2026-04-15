import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/friend_tile.dart';
import '../../../core/models/location_model.dart';
import '../../../core/services/mock_data.dart';
import '../../../core/utils/extensions.dart';
import '../viewmodels/ride_viewmodel.dart';

class ScheduleRideScreen extends StatefulWidget {
  const ScheduleRideScreen({super.key});

  @override
  State<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends State<ScheduleRideScreen> {
  int _step = 0;
  final _meetCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final vm = context.read<RideViewModel>();
    vm.resetForm();
    vm.setImmediate(false);
  }

  @override
  void dispose() { _meetCtrl.dispose(); super.dispose(); }

  void _nextStep() => setState(() => _step++);
  void _prevStep() {
    if (_step > 0) setState(() => _step--);
    else context.pop();
  }

  Future<void> _finish() async {
    final vm = context.read<RideViewModel>();
    if (vm.scheduledAt == null) {
      context.showSnack('Defina data e hora do rolê', isError: true);
      return;
    }
    final ride = await vm.saveRide();
    if (ride != null && mounted) {
      context.showSnack('Rolê agendado para ${ride.scheduledAt!.formattedDateTime}!');
      context.go('/rides/${ride.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RideViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendar Rolê'),
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
        Text('Adicione participantes', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        ...MockData.friends.map((u) => FriendTile(user: u, selected: vm.isParticipant(u), onTap: () => vm.toggleParticipant(u), actions: [])),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(label: 'Próximo', icon: Icons.arrow_forward, iconTrailing: true, onPressed: _nextStep),
      ],
    );
  }

  Widget _buildStep1(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Defina o ponto de encontro', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        AppInput(
          controller: _meetCtrl,
          label: 'Ponto de encontro',
          hint: 'Endereço ou ponto de referência',
          prefixIcon: Icons.location_on,
          onChanged: (v) => vm.setMeetingPoint(LocationModel(lat: -27.5954, lng: -48.5480, address: v)),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(label: 'Próximo', icon: Icons.arrow_forward, iconTrailing: true, onPressed: _meetCtrl.text.isNotEmpty ? _nextStep : null),
      ],
    );
  }

  Widget _buildStep2(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Defina data e hora', style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (date != null && context.mounted) {
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (time != null) {
                vm.setScheduledAt(DateTime(date.year, date.month, date.day, time.hour, time.minute));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(AppSpacing.radiusMd), border: Border.all(color: vm.scheduledAt != null ? AppColors.teal : AppColors.divider, width: vm.scheduledAt != null ? 1.5 : 1)),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: vm.scheduledAt != null ? AppColors.teal : AppColors.textMuted, size: 20),
                const SizedBox(width: AppSpacing.md),
                Text(
                  vm.scheduledAt != null ? vm.scheduledAt!.formattedDateTime : 'Selecionar data e hora',
                  style: AppTextStyles.bodyMedium.copyWith(color: vm.scheduledAt != null ? AppColors.textPrimary : AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(label: 'Agendar Rolê', icon: Icons.calendar_today, isLoading: vm.isSaving, onPressed: _finish),
      ],
    );
  }
}
