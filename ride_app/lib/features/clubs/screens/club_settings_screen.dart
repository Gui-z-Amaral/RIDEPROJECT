import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/club_viewmodel.dart';
import '../../../core/models/club_invite.dart';
import '../../../core/constants/app_links.dart';
import '../../../core/utils/share_utils.dart';
import '../../../core/services/supabase_club_service.dart';

/// Configurações do motoclube (dono/gerente): banner, nome, cidade/UF,
/// descrição e atalho para gerenciar membros.
class ClubSettingsScreen extends StatefulWidget {
  final String clubId;
  const ClubSettingsScreen({super.key, required this.clubId});

  @override
  State<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends State<ClubSettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _ufCtrl;
  late final TextEditingController _descCtrl;

  String? _bannerUrl;
  String? _logoUrl;
  bool _uploadingBanner = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final club = context.read<ClubViewModel>().selected;
    _nameCtrl = TextEditingController(text: club?.name ?? '');
    _cityCtrl = TextEditingController(text: club?.city ?? '');
    _ufCtrl = TextEditingController(text: club?.stateUf ?? '');
    _descCtrl = TextEditingController(text: club?.description ?? '');
    _bannerUrl = club?.bannerUrl;
    _logoUrl = club?.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _ufCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploadingBanner = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final bytes = await file.readAsBytes();
      final url = await StorageUtils.uploadImageUnique(
        bucket: 'avatars',
        uid: uid,
        prefix: 'club_banner',
        bytes: bytes,
        previousUrl: _bannerUrl,
      );
      if (mounted) setState(() => _bannerUrl = url);
    } catch (e) {
      if (mounted) {
        context.showSnack('Erro ao enviar banner: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploadingLogo = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final bytes = await file.readAsBytes();
      final url = await StorageUtils.uploadImageUnique(
        bucket: 'avatars',
        uid: uid,
        prefix: 'club_logo',
        bytes: bytes,
        previousUrl: _logoUrl,
      );
      if (mounted) setState(() => _logoUrl = url);
    } catch (e) {
      if (mounted) {
        context.showSnack('Erro ao enviar logo: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    final vm = context.read<ClubViewModel>();
    // O id vem da tela, não do `selected` do ViewModel: eram duas fontes de
    // verdade para a mesma coisa.
    final ok = await vm.updateClub(
      widget.clubId,
      name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      stateUf: _ufCtrl.text.trim().toUpperCase(),
      bannerUrl: _bannerUrl,
      avatarUrl: _logoUrl,
    );
    if (!mounted) return;
    if (ok) {
      context.showSnack('Configurações salvas!');
      context.pop();
    } else {
      context.showSnack(vm.saveError ?? 'Erro ao salvar.', isError: true);
    }
  }

  /// Folha de convites: gera o link e compartilha. Fica aqui e nao numa
  /// tela propria porque sao tres botoes — tela inteira seria peso a toa.
  Future<void> _abrirConvites(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ConvitesSheet(clubId: widget.clubId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClubViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Configurações',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
        children: [
          const _Label('BANNER'),
          GestureDetector(
            onTap: _uploadingBanner ? null : _pickBanner,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12),
                image: (_bannerUrl != null && _bannerUrl!.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(_bannerUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: _uploadingBanner
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.navy))
                  : (_bannerUrl == null || _bannerUrl!.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: AppColors.textMuted, size: 32),
                              const SizedBox(height: 6),
                              Text('Fazer upload',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Trocar banner',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 20),

          const _Label('LOGO'),
          Center(
            child: GestureDetector(
              onTap: _uploadingLogo ? null : _pickLogo,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.inputFill,
                      backgroundImage:
                          (_logoUrl != null && _logoUrl!.isNotEmpty)
                              ? NetworkImage(_logoUrl!)
                              : null,
                      child: _uploadingLogo
                          ? CircularProgressIndicator(color: AppColors.navy)
                          : (_logoUrl == null || _logoUrl!.isEmpty)
                              ? Icon(Icons.shield_moon_outlined,
                                  color: AppColors.textMuted, size: 36)
                              : null,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const _Label('NOME DO MOTOCLUBE'),
          _Input(controller: _nameCtrl, hint: 'Nome do clube'),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('CIDADE'),
                    _Input(controller: _cityCtrl, hint: 'Cidade'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('UF'),
                    _Input(
                        controller: _ufCtrl, hint: 'SC', textCapsUpper: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const _Label('DESCRIÇÃO'),
          _Input(
            controller: _descCtrl,
            hint: 'Sobre o clube, valores, região...',
            maxLines: 4,
          ),
          const SizedBox(height: 24),

          // A visibilidade deixou de ser do clube inteiro: agora cada evento
          // e cada viagem é marcada como pública ou privada na tela de
          // criação (migration 034).

          // ── Gerenciar membros ──────────────────────────────
          const _Label('MEMBROS'),
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Gerenciar membros',
            subtitle: 'Promover a gerente, expulsar membros',
            onTap: () => context.push('/clubs/${widget.clubId}/members/manage'),
          ),
          _SettingsTile(
            icon: Icons.link,
            title: 'Convidar por link',
            subtitle: 'Permanente, individual ou que expira em 1 hora',
            onTap: () => _abrirConvites(context),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: vm.isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('SALVAR', style: AppTextStyles.labelLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          )),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool textCapsUpper;
  const _Input({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.textCapsUpper = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapsUpper
          ? TextCapitalization.characters
          : TextCapitalization.sentences,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.navy, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Folha de geração de convites por link.
///
/// O token é a credencial: quem tem o link entra. Por isso o botão principal é
/// **compartilhar** (que joga direto no WhatsApp) e não "copiar" — reduz a
/// chance de o link ficar perdido na área de transferência.
class _ConvitesSheet extends StatefulWidget {
  final String clubId;
  const _ConvitesSheet({required this.clubId});

  @override
  State<_ConvitesSheet> createState() => _ConvitesSheetState();
}

class _ConvitesSheetState extends State<_ConvitesSheet> {
  ClubInviteKind? _gerando;

  Future<void> _gerar(ClubInviteKind kind) async {
    setState(() => _gerando = kind);
    try {
      final token = await SupabaseClubService.createInvite(widget.clubId, kind);
      if (!mounted) return;
      await ShareUtils.shareLink(
        title: 'Convite para o meu motoclube no RideApp',
        url: AppLinks.clubInvite(token),
        extra: kind == ClubInviteKind.temporary
            ? 'Este convite vale por 1 hora.'
            : null,
      );
    } catch (e) {
      if (mounted) {
        context.showSnack('Não foi possível gerar o convite: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _gerando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20,
            16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Convidar por link',
                style: AppTextStyles.titleLarge
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Quem abrir o link vê o convite e entra como membro. '
              'Você pode cancelar um convite a qualquer momento.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            for (final k in ClubInviteKind.values) ...[
              _OpcaoConvite(
                kind: k,
                carregando: _gerando == k,
                habilitado: _gerando == null,
                onTap: () => _gerar(k),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _OpcaoConvite extends StatelessWidget {
  final ClubInviteKind kind;
  final bool carregando;
  final bool habilitado;
  final VoidCallback onTap;

  const _OpcaoConvite({
    required this.kind,
    required this.carregando,
    required this.habilitado,
    required this.onTap,
  });

  IconData get _icone => switch (kind) {
        ClubInviteKind.permanent => Icons.public,
        ClubInviteKind.single => Icons.person_add_alt_1,
        ClubInviteKind.temporary => Icons.timer_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(_icone, color: AppColors.navy),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.label,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(kind.hint,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (carregando)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.ios_share, size: 20, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}
