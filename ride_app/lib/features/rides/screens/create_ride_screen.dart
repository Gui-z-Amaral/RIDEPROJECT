import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/map_placeholder.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/extensions.dart';
import '../viewmodels/ride_viewmodel.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../../active_session/viewmodels/active_session_viewmodel.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  int _step = 0;
  final _meetCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<RideViewModel>().resetForm();
    Future.microtask(() => context.read<SocialViewModel>().loadFriends());
  }

  @override
  void dispose() {
    _meetCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _nextStep() => setState(() => _step++);
  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      context.pop();
    }
  }

  Future<void> _finish() async {
    final vm = context.read<RideViewModel>();
    final ride = await vm.saveRide();
    if (ride != null && mounted) {
      context.read<ActiveSessionViewModel>().startSession(
          id: ride.id, title: ride.title, isRide: true);
      context.showSnack('Rolê criado!');
      context.go('/session/waiting/${ride.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RideViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Novo Rolê',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
            onPressed: _prevStep),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: List.generate(
                  3,
                  (i) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? AppColors.navy
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: [
                _buildStep0(vm),
                _buildStep1(vm),
                _buildStep2(vm)
              ][_step],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Participantes ───────────────────────────────────────────────────

  Widget _buildStep0(RideViewModel vm) {
    final socialVm = context.watch<SocialViewModel>();
    final isSearching = _searchCtrl.text.isNotEmpty;
    final users = isSearching ? socialVm.searchResults : socialVm.friends;
    final loading =
        isSearching ? socialVm.isSearching : socialVm.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quem vai no rolê?',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Selecione amigos ou busque por nome/@username',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // ── Chips dos selecionados ──────────────────────────────
        if (vm.participants.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vm.participants
                .map((p) => _SelectedChip(
                      user: p,
                      onRemove: () => vm.toggleParticipant(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // ── Barra de busca ──────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (q) {
              setState(() {});
              if (q.isEmpty) {
                context.read<SocialViewModel>().search('');
              } else {
                context.read<SocialViewModel>().search(q);
              }
            },
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou @username',
              hintStyle: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        context.read<SocialViewModel>().search('');
                        setState(() {});
                      },
                      child: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Lista de usuários ───────────────────────────────────
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.navy)),
          )
        else if (users.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                isSearching
                    ? 'Nenhum usuário encontrado'
                    : 'Você ainda não tem amigos adicionados',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: users.map((u) {
                final selected = vm.isParticipant(u);
                return Column(
                  children: [
                    InkWell(
                      onTap: () => vm.toggleParticipant(u),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            // Foto de perfil real
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppColors.navy.withOpacity(0.1),
                              backgroundImage: u.avatarUrl != null
                                  ? NetworkImage(u.avatarUrl!)
                                  : null,
                              child: u.avatarUrl == null
                                  ? Text(
                                      u.name.isNotEmpty
                                          ? u.name[0].toUpperCase()
                                          : '?',
                                      style: AppTextStyles.titleMedium
                                          .copyWith(
                                              color: AppColors.navy),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(u.name,
                                      style: AppTextStyles.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (u.username.isNotEmpty)
                                    Text('@${u.username}',
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.navy
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.navy
                                      : AppColors.divider,
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (u != users.last)
                      const Divider(height: 1, indent: 60),
                  ],
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Próximo',
          icon: Icons.arrow_forward,
          iconTrailing: true,
          onPressed: _nextStep,
        ),
      ],
    );
  }

  // ── Step 1: Ponto de encontro ───────────────────────────────────────────────

  Widget _buildStep1(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Onde é o ponto de encontro?',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.xl),
        AppInput(
          controller: _meetCtrl,
          label: 'Ponto de encontro',
          hint: 'Endereço, praça ou ponto de referência',
          prefixIcon: Icons.location_on,
          onChanged: (v) => vm.setMeetingPoint(
              LocationModel(lat: -27.5954, lng: -48.5480, address: v)),
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

  // ── Step 2: Confirmação ─────────────────────────────────────────────────────

  Widget _buildStep2(RideViewModel vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirme os detalhes',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.xl),

        // Summary card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: Colors.red, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(vm.meetingPoint?.address ?? '',
                          style: AppTextStyles.titleMedium)),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              // Participantes com fotos
              Row(
                children: [
                  const Icon(Icons.people,
                      color: AppColors.teal, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                      '${vm.participants.length} participante${vm.participants.length != 1 ? 's' : ''}',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
              if (vm.participants.isNotEmpty) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: vm.participants
                        .map((p) => Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.navy
                                        .withOpacity(0.1),
                                    backgroundImage: p.avatarUrl != null
                                        ? NetworkImage(p.avatarUrl!)
                                        : null,
                                    child: p.avatarUrl == null
                                        ? Text(
                                            p.name.isNotEmpty
                                                ? p.name[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: AppTextStyles
                                                .labelSmall
                                                .copyWith(
                                                    color:
                                                        AppColors.navy),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name.split(' ').first,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(fontSize: 10),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  const Icon(Icons.flash_on,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Rolê imediato',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: Colors.orange)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.teal.withOpacity(0.08),
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.teal, size: 18),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'A rota até o ponto de encontro será calculada pelo Google Maps ao iniciar.',
                  style: TextStyle(color: AppColors.teal, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Iniciar Rolê',
          icon: Icons.play_arrow,
          isLoading: vm.isSaving,
          onPressed: _finish,
        ),
      ],
    );
  }
}

// ─── Selected chip ─────────────────────────────────────────────────────────

class _SelectedChip extends StatelessWidget {
  final UserModel user;
  final VoidCallback onRemove;
  const _SelectedChip({required this.user, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.navy.withOpacity(0.2),
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            user.name.split(' ').first,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.navy),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}
