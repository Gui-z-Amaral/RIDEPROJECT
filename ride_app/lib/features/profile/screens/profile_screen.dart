import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../../trips/viewmodels/trip_viewmodel.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../rides/viewmodels/ride_viewmodel.dart';
import '../../active_session/viewmodels/active_session_viewmodel.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../../events/viewmodels/event_viewmodel.dart';
import '../../../core/constants/business_categories.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/event_model.dart';
import '../../../core/utils/image_utils.dart';
import '../../../shared/widgets/photo_viewer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Guarda o uid pra qual já carregamos os eventos da empresa (evita recarga
  // em todo rebuild). Resetado quando o uid muda.
  String? _eventsLoadedForUid;

  // ── Logout: zera todos os viewmodels antes do signOut ─────
  Future<void> _handleLogout(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    // Captura refs antes do logout (context pode ficar indisponível depois)
    context.read<ProfileViewModel>().reset();
    context.read<HomeViewModel>().reset();
    context.read<SocialViewModel>().reset();
    context.read<TripViewModel>().reset();
    context.read<RideViewModel>().reset();
    context.read<NotificationsViewModel>().reset();
    context.read<EventViewModel>().reset();
    context.read<ActiveSessionViewModel>().endSession();

    await auth.logout();
    if (context.mounted) context.go('/login');
  }

  // ── Photo upload ──────────────────────────────────────────
  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.navy),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.navy),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null || !mounted) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      // pasta uid/ garante que a policy de RLS aceite o upload
      final fileName = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await file.readAsBytes();
      final jpeg = await ImageUtils.compressToJpeg(bytes);
      await Supabase.instance.client.storage
          .from('user-photos')
          .uploadBinary(fileName, jpeg,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = Supabase.instance.client.storage
          .from('user-photos')
          .getPublicUrl(fileName);
      if (!mounted) return;
      await context.read<ProfileViewModel>().addPhoto(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar foto. Tente novamente.')),
      );
    }
  }

  // ── Trip bottom sheet ─────────────────────────────────────
  Future<void> _showTripSheet(TripModel t) async {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final isOwner = t.creator.id == myId;
    final parts = t.destination.address?.split(',') ?? [];
    final city = parts.isNotEmpty ? parts.first.trim() : t.title;

    // O sheet retorna 'view' ou 'delete' — a ação só roda APÓS o sheet
    // estar totalmente fechado, evitando barreira residual na tela.
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(sheetCtx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(t.title,
                style: AppTextStyles.headlineMedium
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(city,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _SheetInfoRow(icon: Icons.radio_button_on,
                color: AppColors.teal,
                label: t.origin.address ?? t.origin.label ?? 'Origem'),
            if (t.waypoints.isNotEmpty)
              ...t.waypoints.map((w) => _SheetInfoRow(
                  icon: Icons.place, color: AppColors.warning,
                  label: w.address ?? w.label ?? 'Parada')),
            _SheetInfoRow(icon: Icons.location_on,
                color: AppColors.error,
                label: t.destination.address ?? t.destination.label ?? 'Destino'),
            if (t.scheduledAt != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${t.scheduledAt!.day.toString().padLeft(2, '0')}/${t.scheduledAt!.month.toString().padLeft(2, '0')}/${t.scheduledAt!.year}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ]),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(sheetCtx, 'view'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Ver detalhes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.navy),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetCtx, 'delete'),
                  icon: Icon(isOwner ? Icons.delete_outline : Icons.exit_to_app, size: 16),
                  label: Text(isOwner ? 'Excluir' : 'Sair'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'view') {
      // Wait for the bottom sheet dismiss animation to fully complete
      // before pushing the new route, to avoid the barrier overlay staying visible.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      context.push('/trips/${t.id}');
      return;
    }

    // action == 'delete'
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isOwner ? 'Excluir viagem' : 'Sair da viagem'),
        content: Text(isOwner
            ? 'Deseja excluir "${t.title}"?'
            : 'Deseja sair de "${t.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(isOwner ? 'Excluir' : 'Sair',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final vm = context.read<TripViewModel>();
      if (isOwner) {
        await vm.deleteTrip(t.id);
      } else {
        await vm.leaveTrip(t.id);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ProfileViewModel>().load();
      context.read<SocialViewModel>().loadAll();
      context.read<TripViewModel>().loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final socialVm = context.watch<SocialViewModel>();
    final tripVm = context.watch<TripViewModel>();
    final eventVm = context.watch<EventViewModel>();
    final user = vm.user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Carrega os eventos da empresa uma vez por usuário (perfil empresa).
    if ((user?.isBusiness ?? false) && user!.id != _eventsLoadedForUid) {
      _eventsLoadedForUid = user.id;
      Future.microtask(() {
        if (mounted) context.read<EventViewModel>().loadMyEvents(user.id);
      });
    }

    // Separa viagens ativas/planejadas vs concluídas
    final ongoingTrips = tripVm.trips
        .where((t) =>
            t.status != TripStatus.completed &&
            t.status != TripStatus.cancelled)
        .toList();
    final completedTrips = tripVm.trips
        .where((t) => t.status == TripStatus.completed)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                // Botão amigos com badge de pendentes
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.people_outline,
                          color: AppColors.navy),
                      onPressed: () => context.push('/friends'),
                    ),
                    if (socialVm.pendingCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              '${socialVm.pendingCount}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Buscar / adicionar amigos
                IconButton(
                  icon: const Icon(Icons.person_add_outlined,
                      color: AppColors.navy),
                  onPressed: () => context.push('/friends/search'),
                ),
                // Configurações
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.navy),
                  onPressed: () => context.push('/profile/settings'),
                ),
                // Logout
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.navy),
                  onPressed: () => _handleLogout(context),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: (user?.isBusiness ?? false)
                ? _buildBusinessBody(user, vm, eventVm, bottomPad)
                : Column(
              children: [
                // ── Avatar + nome ───────────────────────────────
                const SizedBox(height: 8),
                GestureDetector(
                  // Toque abre a foto de perfil ampliada
                  onTap: user?.avatarUrl != null
                      ? () => showPhotoViewer(context, urls: [user!.avatarUrl!])
                      : null,
                  child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          (user?.name.isNotEmpty == true)
                              ? user!.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy),
                        )
                      : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (user?.name ?? '').toUpperCase(),
                  style: AppTextStyles.headlineLarge
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                if (user?.username.isNotEmpty == true)
                  Text('@${user!.username}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 20),

                // ── Stats 2x2 ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _StatBox(
                          value: '${user?.tripsCount ?? 0}',
                          label: 'Viagens\ncriadas'),
                      const SizedBox(width: 12),
                      _StatBox(value: '0', label: 'Rolês'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _StatBox(
                          value: '${socialVm.friends.isNotEmpty ? socialVm.friends.length : (user?.friendsCount ?? 0)}',
                          label: 'Amigos\nadicionados'),
                      const SizedBox(width: 12),
                      _StatBox(
                          value: '${completedTrips.length}',
                          label: 'Viagens\nconcluídas'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Editar perfil button ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/profile/edit'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.navy, width: 1.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('EDITAR PERFIL',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.navy,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),

                // ── Bio ────────────────────────────────────────
                if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio',
                            style: AppTextStyles.headlineMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(user.bio!,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary,
                                    height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                ],

                // ── Seus contatos ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Seus Contatos',
                          style: AppTextStyles.headlineMedium
                              .copyWith(fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () => context.push('/friends'),
                        child: Text('Ver todos',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.navy)),
                      ),
                    ],
                  ),
                ),
                if (socialVm.friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => context.push('/friends/search'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_add_outlined,
                                color: AppColors.navy.withOpacity(0.5),
                                size: 28),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nenhum amigo ainda',
                                    style: AppTextStyles.bodyMedium),
                                Text('Toque para buscar riders',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.navy)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: socialVm.friends.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, i) =>
                          _ContactCard(user: socialVm.friends[i]),
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(height: 1),

                // ── Suas fotos ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Suas Fotos',
                          style: AppTextStyles.headlineMedium
                              .copyWith(fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () => _pickAndUploadPhoto(context),
                        child: Row(
                          children: [
                            const Icon(Icons.add_a_photo_outlined,
                                color: AppColors.navy, size: 18),
                            const SizedBox(width: 4),
                            Text('Adicionar',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.navy)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (user?.photos.isEmpty != false)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => _pickAndUploadPhoto(context),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.navy.withOpacity(0.4),
                                  size: 28),
                              const SizedBox(height: 4),
                              Text('Adicionar fotos',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: user!.photos.take(6).length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4),
                      itemBuilder: (_, i) => GestureDetector(
                        // Abre o visualizador na foto tocada (swipe entre todas)
                        onTap: () => showPhotoViewer(context,
                            urls: user.photos, initialIndex: i),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(user.photos[i],
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(height: 1),

                // ── Viagens ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Viagens',
                          style: AppTextStyles.headlineMedium
                              .copyWith(fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () => context.go('/trips'),
                        child: Text('Ver todas',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.navy)),
                      ),
                    ],
                  ),
                ),
                if (ongoingTrips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Nenhuma viagem ainda',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...ongoingTrips.take(3).map((t) {
                    final parts =
                        t.destination.address?.split(',') ?? [];
                    final city = parts.isNotEmpty
                        ? parts.first.trim()
                        : t.title;
                    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
                    final isOwner = t.creator.id == myId;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: GestureDetector(
                        onTap: () => _showTripSheet(t),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.landscape,
                                  color: Colors.white54, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(city.toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    if (t.scheduledAt != null)
                                      Text(
                                        '${t.scheduledAt!.day.toString().padLeft(2, '0')}/${t.scheduledAt!.month.toString().padLeft(2, '0')}/${t.scheduledAt!.year}',
                                        style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                isOwner ? Icons.delete_outline : Icons.exit_to_app,
                                color: Colors.white54,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                // ── Viagens Concluídas ─────────────────────────
                if (completedTrips.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Viagens Concluídas',
                            style: AppTextStyles.headlineMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${completedTrips.length}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.teal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...completedTrips.map((t) {
                    final parts =
                        t.destination.address?.split(',') ?? [];
                    final city = parts.isNotEmpty
                        ? parts.first.trim()
                        : t.title;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: GestureDetector(
                        onTap: () => context.push('/trips/${t.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.flag,
                                    color: AppColors.teal, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(city.toUpperCase(),
                                        style: AppTextStyles.titleSmall
                                            .copyWith(
                                                fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.teal
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'ENCERRADA',
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                              color: AppColors.teal,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ),
                                        if (t.scheduledAt != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '${t.scheduledAt!.day.toString().padLeft(2, '0')}/${t.scheduledAt!.month.toString().padLeft(2, '0')}/${t.scheduledAt!.year}',
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                    color:
                                                        AppColors.textMuted,
                                                    fontSize: 11),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.textMuted, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                SizedBox(height: bottomPad + 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Layout do perfil EMPRESA. Renderizado quando user.isBusiness é true.
  // Mantém o mesmo AppBar do perfil pessoal (amigos / convidar / settings /
  // sair); só o body muda.
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBusinessBody(
      UserModel? user, ProfileViewModel vm, EventViewModel eventVm,
      double bottomPad) {
    final categoriesLabels =
        resolveBusinessCategoryLabels(user?.businessCategories ?? const []);
    final typeLabel = categoriesLabels.isEmpty
        ? 'Tipo de estabelecimento'
        : (categoriesLabels.length > 2
            ? '${categoriesLabels.take(2).join(' · ')} · +${categoriesLabels.length - 2}'
            : categoriesLabels.join(' · '));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ── Banner ───────────────────────────────────────────
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(12),
              image: (user?.businessBannerUrl != null)
                  ? DecorationImage(
                      image: NetworkImage(user!.businessBannerUrl!),
                      fit: BoxFit.cover)
                  : null,
            ),
            child: (user?.businessBannerUrl == null)
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                            color: AppColors.navy.withOpacity(0.4), size: 36),
                        const SizedBox(height: 6),
                        Text('Foto de banner da empresa',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // ── Nome + tipo ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  (user?.displayName ?? '').toUpperCase(),
                  style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800, fontSize: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoriesLabels.isEmpty
                        ? Colors.transparent
                        : AppColors.teal.withOpacity(0.15),
                    border: Border.all(
                        color: categoriesLabels.isEmpty
                            ? AppColors.divider
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 12,
                          color: categoriesLabels.isEmpty
                              ? AppColors.textMuted
                              : AppColors.teal),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(typeLabel,
                            style: AppTextStyles.labelSmall.copyWith(
                                color: categoriesLabels.isEmpty
                                    ? AppColors.textMuted
                                    : AppColors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Editar perfil empresa ────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.push('/profile/business/edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text('EDITAR O PERFIL DA SUA EMPRESA',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ),

          const SizedBox(height: 12),

          // ── Descrição (se preenchida) ────────────────────────
          if ((user?.businessDescription?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(user!.businessDescription!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // ── Eventos ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seus eventos',
                  style: AppTextStyles.headlineMedium
                      .copyWith(fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: () => context.push('/events/create'),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: AppColors.navy, size: 18),
                    const SizedBox(width: 4),
                    Text('Criar',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.navy)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (eventVm.isLoadingMine && eventVm.myEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.navy)),
            )
          else if (eventVm.myEvents.isEmpty)
            _BusinessEmptyCard(
              icon: Icons.event_outlined,
              title: 'Nenhum evento criado',
              subtitle: 'Toque para criar',
              onTap: () => context.push('/events/create'),
            )
          else
            ...eventVm.myEvents.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BusinessEventTile(
                    event: e,
                    onTap: () => context.push('/events/${e.id}'),
                  ),
                )),

          const SizedBox(height: 24),

          // ── Seus anúncios ────────────────────────────────────
          Text('Seus anúncios',
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _BusinessEmptyCard(
            icon: Icons.campaign_outlined,
            title: 'Nenhum anúncio publicado',
            subtitle: 'Toque para publicar',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Publicação de anúncios chega em breve.')),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(height: 1),
          const SizedBox(height: 20),

          // ── Voltar para perfil pessoal ───────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: vm.isSaving
                  ? null
                  : () async {
                      final ok = await vm.setAccountType('personal');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(ok
                                ? 'Voltou para o perfil pessoal.'
                                : 'Não foi possível alterar agora.')),
                      );
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.navy, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('VOLTAR PARA O PERFIL PESSOAL',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ),

          SizedBox(height: bottomPad + 40),
        ],
      ),
    );
  }
}

// ─── Business event tile ─────────────────────────────────────────────────────

class _BusinessEventTile extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  const _BusinessEventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = event.startsAt;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: event.bannerUrl != null
                    ? Image.network(event.bannerUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.white24,
                            child: const Icon(Icons.event,
                                color: Colors.white70, size: 22)))
                    : Container(
                        color: Colors.white24,
                        child: const Icon(Icons.event,
                            color: Colors.white70, size: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(dateLabel,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11)),
                      const SizedBox(width: 10),
                      const Icon(Icons.people,
                          color: Colors.white54, size: 12),
                      const SizedBox(width: 3),
                      Text('${event.interestsCount}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Business empty card ─────────────────────────────────────────────────────

class _BusinessEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BusinessEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(icon,
                  color: AppColors.navy.withOpacity(0.4), size: 36),
              const SizedBox(height: 10),
              Text(title,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.navy)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sheet info row ───────────────────────────────────────────────────────────

class _SheetInfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SheetInfoRow({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ─── Stat box ─────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ─── Contact card ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final UserModel user;
  const _ContactCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/${user.id}', extra: user),
      child: Container(
      width: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.navy.withOpacity(0.1),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.name.isNotEmpty
                        ? user.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            user.name.split(' ').first,
            style: AppTextStyles.labelSmall
                .copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      context.push('/friends/chat/${user.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text('MSG',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),  // Container
    );  // GestureDetector
  }
}
