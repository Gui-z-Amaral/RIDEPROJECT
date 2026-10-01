import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/share_preview.dart';
import '../../../core/services/supabase_share_service.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../events/screens/event_detail_screen.dart';
import '../../rides/screens/ride_detail_screen.dart';
import '../../trips/screens/trip_detail_screen.dart';
import '../../../shared/widgets/formatted_text.dart';

/// Porta de entrada dos links compartilhados (`/e/<id>`, `/v/<id>`, `/r/<id>`).
///
/// Quem já está logado vai direto para a tela de detalhe de sempre. Quem chegou
/// de fora — do WhatsApp, do Instagram — vê uma prévia pública e um convite
/// para entrar ou criar conta. Antes o link caía na tela de detalhe, que não
/// carrega nada sem sessão.
class SharedLinkScreen extends StatelessWidget {
  final ShareKind kind;
  final String id;

  const SharedLinkScreen({super.key, required this.kind, required this.id});

  Widget _detail() => switch (kind) {
        ShareKind.event => EventDetailScreen(eventId: id),
        ShareKind.trip => TripDetailScreen(tripId: id),
        ShareKind.ride => RideDetailScreen(rideId: id),
      };

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    // Ouve o estado da sessão em vez de ler uma vez: ao abrir um link a
    // sessão pode ainda estar sendo restaurada do armazenamento local, e uma
    // leitura única mostraria "Criar conta" para quem já está logado. Também
    // cobre a volta do login, que reaproveita esta mesma rota.
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) =>
          auth.currentUser != null ? _detail() : _PublicPreview(kind: kind, id: id),
    );
  }
}

class _PublicPreview extends StatefulWidget {
  final ShareKind kind;
  final String id;
  const _PublicPreview({required this.kind, required this.id});

  @override
  State<_PublicPreview> createState() => _PublicPreviewState();
}

class _PublicPreviewState extends State<_PublicPreview> {
  late final Future<SharePreview?> _future =
      SupabaseShareService.preview(widget.kind, widget.id);

  /// Depois de entrar, a pessoa volta para o conteúdo que veio ver — e não
  /// para a home, que seria perder o motivo do clique.
  String get _next => '/${widget.kind.path}/${widget.id}';

  void _goAuth(String route) =>
      context.push('$route?next=${Uri.encodeQueryComponent(_next)}');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<SharePreview?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingWidget();
          }
          final p = snap.data;
          if (p == null) return _notFound();
          return _content(p);
        },
      ),
    );
  }

  Widget _notFound() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off, size: 56, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text('Link indisponível',
                  style: AppTextStyles.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Este conteúdo foi removido ou o link está incorreto.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: 'Conhecer o RideApp', onPressed: () => _goAuth('/login')),
            ],
          ),
        ),
      );

  Widget _content(SharePreview p) {
    // Evento mostra tudo (é público por natureza). Viagem e rolê mostram só o
    // essencial — ver SharePreview.
    final isEvent = p.kind == ShareKind.event;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: AppColors.navy,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(p.title,
                style: AppTextStyles.titleMedium
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            background: _banner(p),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chip(p.kind.label),
                const SizedBox(height: AppSpacing.md),
                if (p.startsAt != null)
                  _line(Icons.event, p.startsAt!.formattedDateTime),
                if (p.placeLabel != null) _line(Icons.place_outlined, p.placeLabel!),
                if (p.organizerName != null)
                  _line(Icons.person_outline, 'Por ${p.organizerName}'),
                if (isEvent &&
                    p.description != null &&
                    p.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  FormattedText(p.description!,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: AppSpacing.xl),
                _callToAction(p),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _banner(SharePreview p) {
    final url = p.imageUrl;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navy, AppColors.mediumBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          p.kind == ShareKind.event ? Icons.event : Icons.two_wheeler,
          size: 72,
          color: Colors.white24,
        ),
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
        // Escurece o rodapé para o título ficar legível.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
              stops: [0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
          ],
        ),
      );

  Widget _callToAction(SharePreview p) {
    final what = p.kind == ShareKind.event ? 'o evento' : 'os detalhes';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Entre para ver $what',
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Crie sua conta no RideApp para participar, falar com quem organiza '
            'e acompanhar o trajeto em tempo real.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Criar conta', onPressed: () => _goAuth('/register')),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => _goAuth('/login'),
              child: Text('Já tenho conta — entrar',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.navy, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
