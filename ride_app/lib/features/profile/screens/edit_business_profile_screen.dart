import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/business_categories.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/image_utils.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/profile_viewmodel.dart';

class EditBusinessProfileScreen extends StatefulWidget {
  const EditBusinessProfileScreen({super.key});

  @override
  State<EditBusinessProfileScreen> createState() =>
      _EditBusinessProfileScreenState();
}

class _EditBusinessProfileScreenState extends State<EditBusinessProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _neighborhoodCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;

  final Set<String> _selectedCategories = {};
  bool _uploadingBanner = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<ProfileViewModel>().user;
    _nameCtrl = TextEditingController(text: user?.businessName ?? '');
    _descCtrl = TextEditingController(text: user?.businessDescription ?? '');
    _streetCtrl = TextEditingController(text: user?.businessAddressStreet ?? '');
    _numberCtrl = TextEditingController(text: user?.businessAddressNumber ?? '');
    _neighborhoodCtrl =
        TextEditingController(text: user?.businessAddressNeighborhood ?? '');
    _cityCtrl = TextEditingController(text: user?.businessAddressCity ?? '');
    _stateCtrl = TextEditingController(text: user?.businessAddressState ?? '');
    _selectedCategories.addAll(user?.businessCategories ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final path = '$uid/avatar.jpg';
      final bytes = await file.readAsBytes();
      final jpeg = await ImageUtils.compressToJpeg(bytes);
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: true),
          );
      final url =
          '${Supabase.instance.client.storage.from('avatars').getPublicUrl(path)}'
          '?t=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      await context.read<ProfileViewModel>().updateProfile(avatarUrl: url);
      if (mounted) context.showSnack('Foto de perfil atualizada!');
    } catch (_) {
      if (mounted) context.showSnack('Erro ao atualizar foto.', isError: true);
    }
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() => _uploadingBanner = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final path = '$uid/banner.jpg';
      final bytes = await file.readAsBytes();
      final jpeg = await ImageUtils.compressToJpeg(bytes);
      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: true),
          );
      final url =
          '${Supabase.instance.client.storage.from('avatars').getPublicUrl(path)}'
          '?t=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      await context
          .read<ProfileViewModel>()
          .updateProfile(businessBannerUrl: url);
      if (mounted) context.showSnack('Banner atualizado!');
    } catch (_) {
      if (mounted) context.showSnack('Erro ao enviar banner.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingBanner = false);
    }
  }

  Future<void> _save() async {
    final vm = context.read<ProfileViewModel>();
    final ok = await vm.updateProfile(
      businessName: _nameCtrl.text.trim(),
      businessDescription: _descCtrl.text.trim(),
      businessAddressStreet: _streetCtrl.text.trim(),
      businessAddressNumber: _numberCtrl.text.trim(),
      businessAddressNeighborhood: _neighborhoodCtrl.text.trim(),
      businessAddressCity: _cityCtrl.text.trim(),
      businessAddressState: _stateCtrl.text.trim(),
      businessCategories: _selectedCategories.toList(),
    );
    if (!mounted) return;
    if (ok) {
      context.showSnack(vm.saveError ?? 'Perfil empresa atualizado!',
          isError: vm.saveError != null);
      context.pop();
    } else {
      context.showSnack(vm.saveError ?? 'Erro ao salvar perfil', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final user = vm.user;

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
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.navy, size: 24),
                ),
                const Spacer(),
                Column(
                  children: [
                    Text('EDITAR PERFIL DA EMPRESA',
                        style: AppTextStyles.headlineMedium
                            .copyWith(fontWeight: FontWeight.w800)),
                    Text('Altere suas informações',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const Spacer(),
                const SizedBox(width: 36),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── Banner ────────────────────────────────────
                  _BannerPicker(
                    bannerUrl: user?.businessBannerUrl,
                    uploading: _uploadingBanner,
                    onTap: _uploadingBanner ? null : _pickBanner,
                  ),
                  const SizedBox(height: 20),

                  // ── Foto de perfil ────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor:
                                    AppColors.navy.withOpacity(0.1),
                                backgroundImage: user?.avatarUrl != null
                                    ? NetworkImage(user!.avatarUrl!)
                                    : null,
                                child: user?.avatarUrl == null
                                    ? const Icon(Icons.storefront_outlined,
                                        color: AppColors.navy, size: 36)
                                    : null,
                              ),
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Text('ALTERAR FOTO DE PERFIL',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Razão social ──────────────────────────────
                  const _FieldLabel('RAZÃO SOCIAL OU NOME FANTASIA'),
                  _InputField(
                      controller: _nameCtrl, hint: 'Nome da sua empresa'),
                  const SizedBox(height: 20),

                  // ── Descrição ─────────────────────────────────
                  const _FieldLabel('BREVE DESCRIÇÃO DA EMPRESA'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _descCtrl,
                      maxLines: 5,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Conte sobre seu negócio...',
                        hintStyle: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Endereço ──────────────────────────────────
                  const _FieldLabel('ENDEREÇO'),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _InputField(
                            controller: _streetCtrl, hint: 'Rua'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: _InputField(
                          controller: _numberCtrl,
                          hint: 'Nº',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _InputField(
                            controller: _neighborhoodCtrl, hint: 'Bairro'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InputField(
                            controller: _cityCtrl, hint: 'Cidade'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _InputField(controller: _stateCtrl, hint: 'Estado'),
                  const SizedBox(height: 28),

                  // ── Tipo de comércio ──────────────────────────
                  const _FieldLabel('TIPO DE COMÉRCIO'),
                  const SizedBox(height: 4),
                  ...businessCategoryGroups.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value
                                  .map((cat) => _CategoryChip(
                                        label: cat.label,
                                        selected: _selectedCategories
                                            .contains(cat.id),
                                        onTap: () => setState(() {
                                          if (_selectedCategories
                                              .contains(cat.id)) {
                                            _selectedCategories.remove(cat.id);
                                          } else {
                                            _selectedCategories.add(cat.id);
                                          }
                                        }),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: 12),

                  // ── Salvar ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: vm.isSaving ? null : _save,
                      child: vm.isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('SALVAR',
                              style: AppTextStyles.labelLarge),
                    ),
                  ),
                  SizedBox(height: 40 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Banner picker ────────────────────────────────────────────────────────────

class _BannerPicker extends StatelessWidget {
  final String? bannerUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _BannerPicker({
    required this.bannerUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
          image: bannerUrl != null
              ? DecorationImage(
                  image: NetworkImage(bannerUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: Stack(
          children: [
            if (bannerUrl == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined,
                        color: AppColors.navy.withOpacity(0.4), size: 32),
                    const SizedBox(height: 6),
                    Text('Adicionar foto de banner',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: uploading
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers (mesma estética da tela de editar perfil pessoal) ───────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5)),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.transparent,
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.divider,
              width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
