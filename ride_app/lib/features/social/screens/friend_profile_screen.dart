import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/profile_customization.dart';
import '../../../core/services/supabase_social_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/services/supabase_profile_customization_service.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/framed_avatar.dart';
import '../../../shared/widgets/profile_banner.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../../../core/models/club_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/services/supabase_club_service.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/utils/extensions.dart';

class FriendProfileScreen extends StatefulWidget {
  final UserModel user;
  const FriendProfileScreen({super.key, required this.user});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  List<UserModel> _mutualFriends = [];
  bool _loadingMutual = true;
  ProfileCustomization? _customization;

  // Motoclubes e viagens concluídas — o que a pessoa mostra de si.
  // Quem filtra as viagens é a RLS: só volta o que eu posso ver.
  List<ClubModel> _clubs = [];
  List<TripModel> _trips = [];
  bool _loadingPublic = true;

  /// Perfil recarregado do servidor. `widget.user` pode ter vindo de uma
  /// lista que só trazia nome, @ e foto.
  UserModel? _full;

  // Perfil privado: trava o conteúdo quando não sou amigo.
  bool _privateLocked = false;
  bool _sentRequest = false;

  @override
  void initState() {
    super.initState();
    _checkPrivacy();
    _loadMutual();
    _loadCustomization();
    _loadPublic();
  }

  Future<void> _checkPrivacy() async {
    try {
      // Rebusca o perfil em vez de confiar no que veio na navegação: a lista
      // de busca traz só o básico, e desde a migration 042 os campos íntimos
      // vêm de `profile_details` — que a RLS entrega, ou não, conforme o
      // interruptor de quem é dono do perfil.
      final full = await SupabaseAuthService.getProfileById(widget.user.id);
      if (full == null) return;
      if (mounted) setState(() => _full = full);
      if (!full.isPrivate) return;
      final friends = await SupabaseSocialService.getFriends();
      final isFriend = friends.any((f) => f.id == widget.user.id);
      if (mounted && !isFriend) setState(() => _privateLocked = true);
    } catch (_) {}
  }

  Future<void> _loadPublic() async {
    try {
      final r = await Future.wait([
        SupabaseClubService.getClubsOf(widget.user.id),
        SupabaseTripService.getCompletedTripsOf(widget.user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _clubs = r[0] as List<ClubModel>;
        _trips = r[1] as List<TripModel>;
        _loadingPublic = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPublic = false);
    }
  }

  Future<void> _addFriend() async {
    setState(() => _sentRequest = true);
    try {
      await SupabaseSocialService.sendFriendRequest(widget.user.id);
    } catch (_) {}
  }

  Future<void> _loadCustomization() async {
    try {
      final c = await SupabaseProfileCustomizationService.get(widget.user.id);
      if (mounted) setState(() => _customization = c);
    } catch (_) {}
  }

  Future<void> _loadMutual() async {
    try {
      final list = await SupabaseSocialService.getMutualFriends(widget.user.id);
      if (!mounted) return;
      setState(() {
        _mutualFriends = list;
        _loadingMutual = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMutual = false);
    }
  }

  IconData _iconForStyle(String style) {
    switch (style) {
      case 'Curtas':
        return Icons.route_outlined;
      case 'Longas':
        return Icons.map_outlined;
      case 'Rolês':
        return Icons.groups_outlined;
      default:
        return Icons.two_wheeler;
    }
  }

  // Vista limitada de um perfil privado (para não-amigos).
  Widget _buildLocked(UserModel user) {
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
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.navy.withOpacity(0.1),
                backgroundImage:
                    (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: AppTextStyles.headlineLarge
                            .copyWith(color: AppColors.navy))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(user.name,
                  style: AppTextStyles.headlineSmall
                      .copyWith(fontWeight: FontWeight.w800)),
              if (user.username.isNotEmpty)
                Text('@${user.username}',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Perfil privado',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Adicione como amigo para ver o perfil completo.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sentRequest ? null : _addFriend,
                  icon: Icon(_sentRequest
                      ? Icons.check
                      : Icons.person_add_alt_1),
                  label: Text(_sentRequest
                      ? 'Solicitação enviada'
                      : 'Adicionar amigo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O do servidor quando já chegou; o da navegação enquanto carrega.
    final user = _full ?? widget.user;
    if (_privateLocked) return _buildLocked(user);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // Perfil limpo: cores sempre no padrão, só o banner é personalizável.
    final bgColor = AppColors.background;
    final textColor = AppColors.textPrimary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
              onPressed: () => context.pop(),
            ),
            title: Text(
              user.name.toUpperCase(),
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: bgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Banner personalizado ─────────────────────────
                  if (_customization?.bannerUrl != null)
                    ProfileBannerView(value: _customization!.bannerUrl),
                  SizedBox(height: _customization?.bannerUrl != null ? 0 : 16),

                  // ── Avatar com moldura + indicador online ────────────
                  Transform.translate(
                    offset: Offset(
                      0,
                      _customization?.bannerUrl != null ? -36 : 0,
                    ),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        FramedAvatar(
                          imageUrl: user.avatarUrl,
                          name: user.name,
                          frameId: 'none',
                          size: 104,
                          onTap: user.avatarUrl != null
                              ? () => showPhotoViewer(
                                  context,
                                  urls: [user.avatarUrl!],
                                )
                              : null,
                        ),
                        if (user.isOnline)
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: bgColor, width: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(
                      0,
                      _customization?.bannerUrl != null ? -24 : 0,
                    ),
                    child: Text(
                      user.name.toUpperCase(),
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (user.username.isNotEmpty)
                    Text(
                      '@${user.username}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  if (user.city != null && user.city!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.city!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Stats ─────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        _StatBox(
                          value: '${user.tripsCount}',
                          label: 'Viagens\ncriadas',
                          outlineColor: textColor,
                          fillColor: bgColor,
                        ),
                        const SizedBox(width: 10),
                        _StatBox(
                          value: '${user.friendsCount}',
                          label: 'Amigos\nadicionados',
                          outlineColor: textColor,
                          fillColor: bgColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Moto ──────────────────────────────────────────────
                  if (user.motoModel != null && user.motoModel!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.motorcycle,
                              color: AppColors.teal,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.motoModel!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (user.motoYear != null &&
                                    user.motoYear!.isNotEmpty)
                                  Text(
                                    user.motoYear!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Estilo de viagem preferido ───────────────────────
                  if (user.tripStyle != null && user.tripStyle!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estilo de viagem preferido',
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull,
                                ),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _iconForStyle(user.tripStyle!),
                                    size: 16,
                                    color: AppColors.navy,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.tripStyle!,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Bio ───────────────────────────────────────────────
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bio',
                            style: AppTextStyles.headlineMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.bio!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Motoclubes ───────────────────────────────────────
                  if (!_loadingPublic && _clubs.isNotEmpty) ...[
                    _PerfilSecao(
                      titulo: 'Motoclubes',
                      contagem: _clubs.length,
                      filhos: _clubs
                          .map((c) => _LinhaPerfil(
                                icone: Icons.groups_outlined,
                                titulo: c.name,
                                subtitulo: [
                                  if ((c.city ?? '').isNotEmpty) c.city!,
                                  if ((c.stateUf ?? '').isNotEmpty) c.stateUf!,
                                ].join(' · '),
                                onTap: () => context.push('/clubs/${c.id}'),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Viagens concluídas ───────────────────────────────
                  if (!_loadingPublic && _trips.isNotEmpty) ...[
                    _PerfilSecao(
                      titulo: 'Viagens concluídas',
                      contagem: _trips.length,
                      filhos: _trips
                          .map((t) => _LinhaPerfil(
                                icone: Icons.route_outlined,
                                titulo: t.title,
                                subtitulo: [
                                  t.destination.address
                                          ?.split(',')
                                          .first
                                          .trim() ??
                                      t.destination.label ??
                                      '',
                                  t.scheduledAt?.formattedDate ?? '',
                                ].where((e) => e.isNotEmpty).join(' · '),
                                onTap: () => context.push('/trips/${t.id}'),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Amigos em comum ──────────────────────────────────
                  _MutualFriendsSection(
                    loading: _loadingMutual,
                    friends: _mutualFriends,
                  ),

                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Botão Mensagem ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/friends/chat/${user.id}'),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('ENVIAR MENSAGEM'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: bottomPad + 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  // Cores de personalização: contorno na cor de texto, fundo na cor de
  // background que o dono do perfil escolheu (null = usa o padrão do app).
  final Color? outlineColor;
  final Color? fillColor;
  const _StatBox({
    required this.value,
    required this.label,
    this.outlineColor,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final outline = outlineColor ?? AppColors.navy;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: fillColor ?? AppColors.inputFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: outline.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.headlineLarge.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: outline,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: outline.withOpacity(0.8),
                height: 1.2,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutualFriendsSection extends StatefulWidget {
  final bool loading;
  final List<UserModel> friends;
  const _MutualFriendsSection({required this.loading, required this.friends});

  @override
  State<_MutualFriendsSection> createState() => _MutualFriendsSectionState();
}

class _MutualFriendsSectionState extends State<_MutualFriendsSection> {
  static const _previewLimit = 6;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Text(
              'Amigos em comum',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.friends.isEmpty) return const SizedBox(height: AppSpacing.md);

    final total = widget.friends.length;
    final visible = _showAll
        ? widget.friends
        : widget.friends.take(_previewLimit).toList();
    final hasMore = total > _previewLimit && !_showAll;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Amigos em comum',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: AppColors.teal),
                ),
                child: Text(
                  '$total',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: visible
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => context.push('/profile/${f.id}', extra: f),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Row(
                        children: [
                          AppAvatar(
                            name: f.name,
                            imageUrl: f.avatarUrl,
                            size: 40,
                            showOnline: true,
                            isOnline: f.isOnline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  style: AppTextStyles.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (f.username.isNotEmpty)
                                  Text(
                                    '@${f.username}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TextButton(
                onPressed: () => setState(() => _showAll = true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  'Ver todos ($total)',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}


// ─── Seções do perfil público (motoclubes, viagens) ─────────────────────────

/// Bloco com título, contagem e uma lista de linhas. Os dois usos (motoclubes
/// e viagens) têm a mesma forma — um widget só evita duas versões do mesmo
/// cabeçalho que vão divergir na primeira mudança de design.
class _PerfilSecao extends StatelessWidget {
  final String titulo;
  final int contagem;
  final List<Widget> filhos;
  const _PerfilSecao({
    required this.titulo,
    required this.contagem,
    required this.filhos,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(titulo,
                  style: AppTextStyles.headlineMedium
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text('$contagem',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...filhos,
        ],
      ),
    );
  }
}

/// Uma linha clicável: ícone, título e uma legenda.
class _LinhaPerfil extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  const _LinhaPerfil({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, size: 19, color: AppColors.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitulo.isNotEmpty)
                    Text(subtitulo,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
