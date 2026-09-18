import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/club_invite.dart';
import '../../../core/services/supabase_club_service.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Tela de quem recebeu um link de convite (`/ci/<token>`).
///
/// Fluxo: a pessoa vê de qual motoclube é o convite **antes** de precisar de
/// conta — a prévia funciona sem sessão de propósito, senão ela teria que se
/// cadastrar às cegas. Ao tocar em entrar:
///  - sem conta → vai para o login com `?next=` de volta para cá, e ao voltar
///    o convite é aceito sozinho (ela já demonstrou a intenção);
///  - com conta → entra na hora.
class ClubInviteScreen extends StatefulWidget {
  final String token;

  /// `true` quando a pessoa está voltando do login e já havia tocado em entrar.
  final bool autoAccept;

  const ClubInviteScreen({
    super.key,
    required this.token,
    this.autoAccept = false,
  });

  @override
  State<ClubInviteScreen> createState() => _ClubInviteScreenState();
}

class _ClubInviteScreenState extends State<ClubInviteScreen> {
  late Future<ClubInvitePreview> _preview =
      SupabaseClubService.previewInvite(widget.token);
  bool _entrando = false;
  bool _jaTentouAuto = false;

  bool get _logado => Supabase.instance.client.auth.currentUser != null;

  @override
  void initState() {
    super.initState();
    // Voltou do login tendo tocado em entrar: conclui sem pedir outro toque.
    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _logado && !_jaTentouAuto) {
          _jaTentouAuto = true;
          _entrar();
        }
      });
    }
  }

  Future<void> _entrar() async {
    if (_entrando) return;

    if (!_logado) {
      // Leva a intenção junto: ao voltar, entra direto.
      final destino = Uri.encodeQueryComponent(
          '/ci/${widget.token}?aceitar=1');
      context.push('/login?next=$destino');
      return;
    }

    setState(() => _entrando = true);
    final r = await SupabaseClubService.acceptInviteLink(widget.token);
    if (!mounted) return;
    setState(() => _entrando = false);

    final preview = await _preview;
    if (!mounted) return;

    switch (r) {
      case 'entrou':
      case 'ja_membro':
        final id = preview.clubId;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r == 'entrou'
              ? 'Você entrou no ${preview.name ?? 'motoclube'}!'
              : 'Você já é membro deste motoclube.'),
        ));
        if (id != null) context.go('/c/$id');
      default:
        // Recarrega a prévia para a tela passar a mostrar o motivo.
        setState(() =>
            _preview = SupabaseClubService.previewInvite(widget.token));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mensagemDeFalha(r)), backgroundColor: AppColors.error),
        );
    }
  }

  String _mensagemDeFalha(String r) => switch (r) {
        'usado' => 'Este convite era individual e já foi utilizado.',
        'expirado' => 'Este convite expirou.',
        'revogado' => 'Este convite foi cancelado pelo motoclube.',
        'sem_sessao' => 'Entre na sua conta para aceitar o convite.',
        _ => 'Convite inválido.',
      };

  @override
  Widget build(BuildContext context) {
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
      body: FutureBuilder<ClubInvitePreview>(
        future: _preview,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingWidget();
          }
          final p = snap.data ?? const ClubInvitePreview();
          return p.isValid ? _convite(p) : _problema(p);
        },
      ),
    );
  }

  Widget _convite(ClubInvitePreview p) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(name: p.name ?? '', imageUrl: p.avatarUrl, size: 96),
              const SizedBox(height: AppSpacing.lg),
              Text('Você foi convidado para',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(p.name ?? 'Motoclube',
                  style: AppTextStyles.headlineMedium
                      .copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                [
                  if (p.place.isNotEmpty) p.place,
                  '${p.members} ${p.members == 1 ? 'membro' : 'membros'}',
                ].join(' · '),
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _logado ? 'Entrar no motoclube' : 'Entrar para aceitar',
                onPressed: _entrando ? null : _entrar,
                isLoading: _entrando,
              ),
              if (!_logado) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Você precisa de uma conta. É rápido — e depois voltamos '
                    'para cá automaticamente.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );

  Widget _problema(ClubInvitePreview p) {
    final (icone, titulo, texto) = switch (p.status) {
      ClubInviteStatus.expirado => (
          Icons.timer_off_outlined,
          'Convite expirado',
          'Este link valia por uma hora. Peça um novo a quem te convidou.'
        ),
      ClubInviteStatus.usado => (
          Icons.person_off_outlined,
          'Convite já utilizado',
          'Era um convite individual e alguém já entrou com ele.'
        ),
      ClubInviteStatus.revogado => (
          Icons.block,
          'Convite cancelado',
          'O motoclube cancelou este convite.'
        ),
      _ => (
          Icons.link_off,
          'Convite inválido',
          'Confira se o link foi copiado por inteiro.'
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(titulo, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(texto,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
                label: 'Ir para o início', onPressed: () => context.go('/home')),
          ],
        ),
      ),
    );
  }
}
