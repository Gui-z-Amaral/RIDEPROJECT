import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/profile_appearance.dart';
import '../../../core/constants/profile_banners.dart';
import '../../../core/models/profile_customization.dart';
import '../../../core/utils/extensions.dart';
import '../../../shared/widgets/framed_avatar.dart';
import '../../../shared/widgets/profile_banner.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/profile_customization_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Configurações > Aparência: banner do perfil, moldura do avatar, cor de
/// fundo e de texto — com prévia ao vivo. As alterações só são salvas ao
/// tocar em SALVAR (o rascunho fica só nesta tela).
class ProfileAppearanceScreen extends StatefulWidget {
  const ProfileAppearanceScreen({super.key});

  @override
  State<ProfileAppearanceScreen> createState() =>
      _ProfileAppearanceScreenState();
}

class _ProfileAppearanceScreenState extends State<ProfileAppearanceScreen> {
  ProfileCustomization? _draft;
  bool _loaded = false;

  String get _uid => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final vm = context.read<ProfileCustomizationViewModel>();
    if (vm.customization == null) {
      await vm.load(_uid);
    }
    if (!mounted) return;
    setState(() {
      _draft = vm.customization ?? ProfileCustomization.empty(_uid);
      _loaded = true;
    });
  }

  Future<void> _save() async {
    if (_draft == null) return;
    final ok = await context.read<ProfileCustomizationViewModel>().save(
      _draft!,
    );
    if (!mounted) return;
    if (ok) {
      context.showSnack('Aparência atualizada!');
      context.pop();
    } else {
      context.showSnack(
        context.read<ProfileCustomizationViewModel>().saveError ??
            'Erro ao salvar',
        isError: true,
      );
    }
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar padrão'),
        content: const Text(
          'Remove o banner, a moldura e as cores personalizadas. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context
        .read<ProfileCustomizationViewModel>()
        .resetToDefault(_uid);
    if (!mounted) return;
    if (ok) {
      setState(() => _draft = ProfileCustomization.empty(_uid));
      context.showSnack('Aparência restaurada para o padrão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileCustomizationViewModel>();
    final user = context.watch<ProfileViewModel>().user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (!_loaded || _draft == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }

    final draft = _draft!;
    final isBusiness = user?.isBusiness ?? false;
    final bgColor = resolveProfileColor(
      draft.backgroundColor,
      AppColors.background,
    );
    final textColor = resolveProfileColor(draft.textColor, AppColors.navy);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Aparência do perfil',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
        children: [
          // ── Prévia ao vivo ───────────────────────────────────
          const _Label('PRÉVIA'),
          const SizedBox(height: 8),
          _LivePreviewCard(
            bannerUrl: draft.bannerUrl,
            avatarUrl: user?.avatarUrl,
            name: user?.name ?? '',
            frameId: draft.avatarFrame,
            backgroundColor: bgColor,
            textColor: textColor,
          ),
          const SizedBox(height: 28),

          // ── Banner ───────────────────────────────────────────
          const _Label('BANNER DO PERFIL'),
          const SizedBox(height: 8),
          if (isBusiness) ...[
            Text(
              'Contas empresa usam a foto de banner definida em '
              '"Editar perfil da empresa".',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/profile/business/edit'),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Editar perfil da empresa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: AppColors.navy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Escolha um banner predefinido. Mais opções em breve.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            _BannerPresetGrid(
              selectedId: draft.bannerUrl,
              onSelect: (id) => setState(
                () => _draft = draft.copyWith(
                  bannerUrl: id == draft.bannerUrl ? null : id,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // ── Moldura do avatar ─────────────────────────────────
          const _Label('MOLDURA DO AVATAR'),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: avatarFrames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final frame = avatarFrames[i];
                final selected = draft.avatarFrame == frame.id;
                return GestureDetector(
                  onTap: () => setState(
                    () => _draft = draft.copyWith(avatarFrame: frame.id),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.navy
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: FramedAvatar(
                          imageUrl: user?.avatarUrl,
                          name: user?.name ?? '',
                          frameId: frame.id,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        frame.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: selected
                              ? AppColors.navy
                              : AppColors.textMuted,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // ── Cor de fundo ───────────────────────────────────────
          const _Label('COR DE FUNDO DO PERFIL'),
          const SizedBox(height: 8),
          Text(
            'Padrão do app se nenhuma for escolhida.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          _ColorPaletteRow(
            selectedId: draft.backgroundColor,
            onSelect: (id) => setState(
              () => _draft = draft.copyWith(
                backgroundColor: id == draft.backgroundColor ? null : id,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Cor do texto ─────────────────────────────────────
          const _Label('COR DO TEXTO'),
          const SizedBox(height: 8),
          Text(
            'Padrão do app se nenhuma for escolhida.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          _ColorPaletteRow(
            selectedId: draft.textColor,
            onSelect: (id) => setState(
              () => _draft = draft.copyWith(
                textColor: id == draft.textColor ? null : id,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Salvar ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: vm.isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('SALVAR', style: AppTextStyles.labelLarge),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: vm.isSaving ? null : _resetToDefault,
              child: Text(
                'Restaurar padrão',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Prévia ao vivo ─────────────────────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  final String? bannerUrl;
  final String? avatarUrl;
  final String name;
  final String frameId;
  final Color backgroundColor;
  final Color textColor;

  const _LivePreviewCard({
    required this.bannerUrl,
    required this.avatarUrl,
    required this.name,
    required this.frameId,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner
            bannerUrl != null
                ? ProfileBannerView(value: bannerUrl, height: 70)
                : Container(
                    height: 70,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.navy, AppColors.mediumBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: FramedAvatar(
                      imageUrl: avatarUrl,
                      name: name,
                      frameId: frameId,
                      size: 56,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Text(
                      name.isNotEmpty ? name.toUpperCase() : 'SEU NOME',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

// ─── Grade de banners predefinidos (contas pessoais) ──────────────────────────

class _BannerPresetGrid extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _BannerPresetGrid({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profileBannerPresets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (_, i) {
        final preset = profileBannerPresets[i];
        final selected = selectedId == preset.id;
        return GestureDetector(
          onTap: () => onSelect(preset.id),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? AppColors.navy : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(preset.assetPath, fit: BoxFit.cover),
                      // Escurece o rodapé para o label ficar legível.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 28,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black54],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 6,
                        child: Text(
                          preset.label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.navy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Paleta de cores ─────────────────────────────────────────────────────────

class _ColorPaletteRow extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _ColorPaletteRow({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: profileColorPalette.map((c) {
        final selected = selectedId == c.id;
        return GestureDetector(
          onTap: () => onSelect(c.id),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.navy : AppColors.divider,
                    width: selected ? 3 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.navy.withOpacity(0.25),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        color: isLightColor(c.color)
                            ? AppColors.navy
                            : Colors.white,
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                c.label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.headlineSmall.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }
}
