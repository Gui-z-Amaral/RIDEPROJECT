import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/geocoding_service.dart';
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
  final _searchCtrl = TextEditingController();
  PlaceInfo? _placeInfo; // info extra do ponto de encontro (horários, etc.)

  @override
  void initState() {
    super.initState();
    context.read<RideViewModel>().resetForm();
    Future.microtask(() => context.read<SocialViewModel>().loadFriends());
  }

  @override
  void dispose() {
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

  List<UserModel> _filterFriends(List<UserModel> friends, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return friends;
    return friends
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _pickMeetingPoint() async {
    final result = await context.push<dynamic>('/map/select', extra: {
      'title': 'Ponto de encontro',
      'onSelected': null,
    });
    if (result == null || !mounted) return;

    LocationModel? loc;
    PlaceInfo? info;
    if (result is Map) {
      loc = result['location'] as LocationModel?;
      info = result['info'] as PlaceInfo?;
    } else if (result is LocationModel) {
      loc = result;
    }
    if (loc == null) return;

    final vm = context.read<RideViewModel>();
    final title = loc.label?.trim().isNotEmpty == true
        ? loc.label!
        : (loc.address?.split(',').first.trim() ?? 'Ponto de encontro');
    vm.setTitle(title);
    vm.setMeetingPoint(loc);
    setState(() => _placeInfo = info);
  }

  Future<void> _finish() async {
    final vm = context.read<RideViewModel>();
    final ride = await vm.saveRide();
    if (!mounted) return;
    if (ride != null) {
      context.read<ActiveSessionViewModel>().startSession(
        id: ride.id,
        title: ride.title,
        isRide: true,
        participants: ride.participants,
      );
      context.showSnack('Rolê criado!');
      // pushReplacement: não volta para o form ao pressionar back,
      // mas preserva a tela anterior (shell) para o back funcionar.
      context.pushReplacement('/session/waiting/${ride.id}');
    } else {
      context.showSnack(
        vm.saveError != null
            ? 'Erro ao criar rolê: ${vm.saveError}'
            : 'Erro ao criar rolê. Tente novamente.',
        isError: true,
      );
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
      body: SafeArea(
        top: false,
        child: Column(
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
      ),
    );
  }

  // ── Step 0: Participantes ───────────────────────────────────────────────────

  Widget _buildStep0(RideViewModel vm) {
    final socialVm = context.watch<SocialViewModel>();
    final users = _filterFriends(socialVm.friends, _searchCtrl.text);
    final loading = socialVm.isLoading;
    final isSearching = _searchCtrl.text.isNotEmpty;

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
            onChanged: (_) => setState(() {}),
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
    final hasMeeting = vm.meetingPoint != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Onde é o ponto de encontro?',
            style: AppTextStyles.headlineMedium
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Busque pelo nome do lugar ou toque no mapa para selecionar',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Card do local selecionado ou botão para selecionar ──
        if (!hasMeeting)
          GestureDetector(
            onTap: _pickMeetingPoint,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_location_alt_outlined,
                      color: AppColors.navy, size: 36),
                  const SizedBox(height: 8),
                  Text('Selecionar ponto de encontro',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text('Busca por nome ou toque no mapa',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          _MeetingPointCard(
            meeting: vm.meetingPoint!,
            info: _placeInfo,
            onClear: () {
              vm.setMeetingPoint(null);
              vm.setTitle('');
              setState(() => _placeInfo = null);
            },
            onEdit: _pickMeetingPoint,
          ),

        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Próximo',
          icon: Icons.arrow_forward,
          iconTrailing: true,
          onPressed: hasMeeting ? _nextStep : null,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.meetingPoint?.label ?? vm.meetingPoint?.address ?? '',
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if ((vm.meetingPoint?.address ?? '').isNotEmpty &&
                            vm.meetingPoint?.label != vm.meetingPoint?.address)
                          Text(
                            vm.meetingPoint!.address!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (_placeInfo?.openNow != null)
                          Text(
                            _placeInfo!.openNow! ? '● Aberto agora' : '● Fechado agora',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: _placeInfo!.openNow!
                                  ? AppColors.success
                                  : AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
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

// ─── Meeting point card ────────────────────────────────────────────────────

class _MeetingPointCard extends StatelessWidget {
  final LocationModel meeting;
  final PlaceInfo? info;
  final VoidCallback onClear;
  final VoidCallback onEdit;

  const _MeetingPointCard({
    required this.meeting,
    required this.info,
    required this.onClear,
    required this.onEdit,
  });

  IconData _icon(String? category) {
    if (category == null) return Icons.location_on;
    if (category.contains('Restaurante')) return Icons.restaurant;
    if (category.contains('Café')) return Icons.coffee;
    if (category.contains('Bar')) return Icons.local_bar;
    if (category.contains('Posto')) return Icons.local_gas_station;
    if (category.contains('Hosped')) return Icons.hotel;
    if (category.contains('Parque') || category.contains('Natural'))
      return Icons.park;
    if (category.contains('Praia')) return Icons.beach_access;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    final name = meeting.label ?? meeting.address ?? 'Local selecionado';
    final address = meeting.address;
    final category = info?.category;
    final openNow = info?.openNow;
    final todayHours = info?.todayHours;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.teal.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon(category),
                      color: AppColors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppTextStyles.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (category != null)
                        Text(category,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted)),
                      if (address != null && address.isNotEmpty)
                        Text(address,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.textMuted),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // ── Horários ───────────────────────────────────────────
          if (openNow != null || todayHours != null) ...[
            const Divider(height: 16, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Row(
                children: [
                  Icon(
                    openNow == true
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 15,
                    color: openNow == true
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  if (openNow != null)
                    Text(
                      openNow ? 'Aberto agora' : 'Fechado agora',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: openNow
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (todayHours != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '· ${todayHours.contains(':') ? todayHours.split(': ').last : todayHours}',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Botão trocar ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: GestureDetector(
              onTap: onEdit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_location_alt,
                      size: 14, color: AppColors.navy),
                  const SizedBox(width: 4),
                  Text('Trocar local',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
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
