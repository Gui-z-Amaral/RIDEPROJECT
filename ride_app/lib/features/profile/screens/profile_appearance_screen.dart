import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/profile_customization.dart';
import '../../../core/utils/extensions.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/profile_customization_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';

/// Configurações > Aparência: modo escuro do app + banner do perfil (imagem
/// livre). Perfil limpo, sem molduras/cores/fotos.
class ProfileAppearanceScreen extends StatefulWidget {
  const ProfileAppearanceScreen({super.key});

  @override
  State<ProfileAppearanceScreen> createState() =>
      _ProfileAppearanceScreenState();
}

class _ProfileAppearanceScreenState extends State<ProfileAppearanceScreen> {
  String? _bannerUrl;
  bool _uploadingBanner = false;
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
      _bannerUrl = vm.customization?.bannerUrl;
      _loaded = true;
    });
  }

  Future<void> _pickBanner() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _uploadingBanner = true);
    try {
      final bytes = await file.readAsBytes();
      final url =
          await context.read<ProfileCustomizationViewModel>().uploadBanner(bytes);
      if (mounted && url != null) setState(() => _bannerUrl = url);
    } catch (e) {
      if (mounted) context.showSnack('Erro ao enviar banner.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _save() async {
    final vm = context.read<ProfileCustomizationViewModel>();
    // Só o banner é personalizável — o resto fica no padrão.
    final ok = await vm.save(ProfileCustomization(
      userId: _uid,
      bannerUrl: _bannerUrl,
      avatarFrame: 'none',
    ));
    if (!mounted) return;
    if (ok) {
      context.showSnack('Aparência atualizada!');
      context.pop();
    } else {
      context.showSnack(vm.saveError ?? 'Erro ao salvar', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileCustomizationViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.navy)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Aparência',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
        children: [
          // ── Modo escuro ─────────────────────────────────────
          const _Label('TEMA DO APLICATIVO'),
          const SizedBox(height: 8),
          _DarkModeSwitch(
            value: context.watch<ThemeViewModel>().isDarkMode,
            onChanged: (v) => context.read<ThemeViewModel>().setDarkMode(v),
          ),
          const SizedBox(height: 28),

          // ── Banner do perfil ────────────────────────────────
          const _Label('BANNER DO PERFIL'),
          const SizedBox(height: 8),
          Text('Uma imagem sua no topo do perfil.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 10),
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
          if (_bannerUrl != null && _bannerUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _bannerUrl = null),
                icon: Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                label: Text('Remover banner',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error)),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // ── Salvar ──────────────────────────────────────────
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

class _DarkModeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DarkModeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.navy,
        secondary: Icon(
          value ? Icons.dark_mode : Icons.dark_mode_outlined,
          color: AppColors.navy,
        ),
        title: Text('Modo escuro', style: AppTextStyles.bodyMedium),
        subtitle: Text(
          'Preto com texto branco em todo o app',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ));
  }
}
