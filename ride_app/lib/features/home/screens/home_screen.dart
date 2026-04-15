import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<HomeViewModel>().load();
      context.read<NotificationsViewModel>().load();
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'BOM DIA';
    if (h < 18) return 'BOA TARDE';
    return 'BOA NOITE';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final unread = context.watch<NotificationsViewModel>().unreadCount;
    final firstName = (user?.name ?? '').split(' ').first.toUpperCase();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final nextTrip = vm.upcomingTrips.isNotEmpty ? vm.upcomingTrips.first : null;
    final nextRide = vm.upcomingRides.isNotEmpty ? vm.upcomingRides.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.navy.withOpacity(0.1),
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            (user?.name.isNotEmpty == true)
                                ? user!.name[0].toUpperCase()
                                : 'U',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.navy),
                          )
                        : null,
                  ),
                ),
                const Spacer(),
                Text('HOME',
                    style: AppTextStyles.headlineMedium
                        .copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: AppColors.navy),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
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
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Saudação ──────────────────────────────────────
                  Text(
                    '${_greeting()} ${firstName.isNotEmpty ? firstName : 'RIDER'} !',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veja o que está te esperando na estrada',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Barra de pesquisa ─────────────────────────────
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pesquise lugares, agendamentos ou pessoas!',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── PRÓXIMA VIAGEM ────────────────────────────────
                  _SectionLabel(label: 'PRÓXIMA VIAGEM'),
                  const SizedBox(height: AppSpacing.sm),
                  nextTrip != null
                      ? _NextTripCard(
                          trip: nextTrip,
                          onTap: () => context.push('/trips/${nextTrip.id}'),
                        )
                      : _EmptyCard(
                          icon: Icons.add_road,
                          message: 'Nenhuma viagem planejada',
                          hint: 'Toque para criar uma nova',
                          onTap: () => context.push('/trips/create'),
                        ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── PRÓXIMO ROLÊ ──────────────────────────────────
                  _SectionLabel(label: 'PRÓXIMO ROLÊ'),
                  const SizedBox(height: AppSpacing.sm),
                  nextRide != null
                      ? _NextRideCard(
                          ride: nextRide,
                          onTap: () => context.push('/rides/${nextRide.id}'),
                        )
                      : _EmptyCard(
                          icon: Icons.groups_outlined,
                          message: 'Nenhum rolê agendado',
                          hint: 'Toque para criar um novo',
                          onTap: () => context.push('/rides/create'),
                        ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── CTAs ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _CtaButton(
                          icon: Icons.two_wheeler,
                          label: 'PLANEJAR UMA\nVIAGEM',
                          onTap: () => context.push('/trips/create'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _CtaButton(
                          icon: Icons.groups,
                          label: 'INICIAR UM\nROLÊ',
                          onTap: () => context.push('/rides/create'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── ENCONTRE EMPRESAS ─────────────────────────────
                  _BusinessSection(
                      onTap: () {}),
                  const SizedBox(height: AppSpacing.lg),

                  // ── SUGESTÕES PARA VOCÊ ───────────────────────────
                  _SectionLabel(label: 'SUGESTÕES PARA VOCÊ'),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),

          // Sugestões (scroll horizontal)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: _mockSuggestions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) =>
                    _SuggestionCard(data: _mockSuggestions[i]),
              ),
            ),
          ),

          SliverToBoxAdapter(
              child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 100)),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.headlineMedium.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    );
  }
}

// ─── Próxima Viagem card ──────────────────────────────────────────────────────

class _NextTripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;
  const _NextTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dest = trip.destination;
    final parts = dest.address?.split(',') ?? [];
    final city = parts.isNotEmpty
        ? parts.first.trim().toUpperCase()
        : trip.title.toUpperCase();
    final state = parts.length > 1 ? parts[1].trim().toUpperCase() : '';
    final stops = trip.stops.length + trip.waypoints.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.navy,
                      AppColors.mediumBlue,
                      AppColors.teal.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.landscape,
                          color: Colors.white.withOpacity(0.15), size: 60),
                    ),
                    // Stops badge
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$stops PARADAS',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.isNotEmpty ? '$city, $state' : city,
                          style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      if (trip.scheduledAt != null)
                        Text(
                          _fmtDate(trip.scheduledAt!),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  if (trip.participants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...trip.participants.take(3).map((p) => Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.navy.withOpacity(0.1),
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  p.name.isNotEmpty
                                      ? p.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            )),
                        if (trip.participants.length > 3)
                          Text(
                            '+${trip.participants.length - 3}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Clique no card para ver as viagens agendadas com detalhes',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_month(d.month).toUpperCase()}';

  String _month(int m) => const [
        '', 'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
        'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'
      ][m];
}

// ─── Próximo Rolê card ────────────────────────────────────────────────────────

class _NextRideCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback onTap;
  const _NextRideCard({required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título do rolê
          Text(
            ride.title.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // Horário
          if (ride.scheduledAt != null) ...[
            Text('HORÁRIO:',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              _fmtDateTime(ride.scheduledAt!),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          // Amigos confirmados
          Text('AMIGOS CONFIRMADOS:',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ride.participants.isEmpty
              ? Text('Nenhum confirmado ainda',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12))
              : Row(
                  children: [
                    ...ride.participants.take(4).map((p) => Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                    if (ride.participants.length > 4)
                      Text('+${ride.participants.length - 4}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11)),
                  ],
                ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text('VER DETALHE',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.navy, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  $h:$m';
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CtaButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Encontre Empresas section ────────────────────────────────────────────────

class _BusinessSection extends StatelessWidget {
  final VoidCallback onTap;
  const _BusinessSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENCONTRE EMPRESAS CONFIÁVEIS',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore postos de combustível, oficinas mecânica, borracharias e outros comércios confiáveis com base na avaliação deles',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.navy, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COMEÇAR A EXPLORAR',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  final VoidCallback onTap;
  const _EmptyCard(
      {required this.icon,
      required this.message,
      required this.hint,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy.withOpacity(0.4), size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTextStyles.bodyMedium),
                Text(hint,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.navy)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Suggestion card ──────────────────────────────────────────────────────────

class _SuggestionData {
  final String name;
  final String location;
  final double rating;
  final List<Color> gradient;
  const _SuggestionData(
      {required this.name,
      required this.location,
      required this.rating,
      required this.gradient});
}

final _mockSuggestions = [
  _SuggestionData(
    name: 'Divina Itália',
    location: 'Aranauga, SC',
    rating: 4.8,
    gradient: [const Color(0xFF6B4E35), const Color(0xFF3D2B1F)],
  ),
  _SuggestionData(
    name: 'Mirante do Vale',
    location: 'Gramado, RS',
    rating: 4.6,
    gradient: [AppColors.navy, AppColors.mediumBlue],
  ),
  _SuggestionData(
    name: 'Café Serra',
    location: 'Canela, RS',
    rating: 4.5,
    gradient: [const Color(0xFF2D5016), const Color(0xFF4A7C25)],
  ),
  _SuggestionData(
    name: 'Praia do Rosa',
    location: 'Imbituba, SC',
    rating: 4.9,
    gradient: [AppColors.teal, const Color(0xFF0891B2)],
  ),
];

class _SuggestionCard extends StatelessWidget {
  final _SuggestionData data;
  const _SuggestionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: data.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Stack(
          children: [
            // Background icon
            Positioned(
              top: 16,
              right: 10,
              child: Icon(Icons.place,
                  color: Colors.white.withOpacity(0.1), size: 60),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        data.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.location,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ver detalhes',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withOpacity(0.9)),
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
