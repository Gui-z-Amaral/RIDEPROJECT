import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _cityCtrl;

  String? _selectedRouteType;
  final Set<String> _selectedTags = {};

  static const _routeTypes = [
    'Gastronômica',
    'Panorâmica',
    'Litorânea',
    'Mais Curta',
  ];

  static const _tagCategories = {
    'Gastronômia': [
      'RESTAURANTES',
      'CAFÉS',
      'PADARIAS',
      'BARES',
      'LANCHONETES',
      'CHURRASCARIAS',
    ],
    'Descanso': [
      'POUSADAS',
      'HOTÉIS',
      'CAMPING',
      'CHALÉ',
      'PERNOITE',
    ],
    'Apoio na estrada': [
      'BORRACHARIA',
      'POSTO DE COMBUSTÍVEL',
      'FARMÁCIA',
      'OFICINA MECÂNICA',
      'CONVENIÊNCIA',
    ],
    'Turismo e lazer': [
      'MIRANTES',
      'CHACHOEIRA',
      'CÂNION',
      'TRILHAS',
      'MUSEU',
      'MONUMENTO',
      'CENTRO HISTÓRICO',
      'PARQUE TURÍSTICO',
    ],
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<ProfileViewModel>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _cityCtrl = TextEditingController(text: user?.city ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      // Sobrescreve sempre o mesmo arquivo para não acumular versões
      final path = '$uid/avatar.jpg';
      final bytes = await file.readAsBytes();
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(path, bytes,
              fileOptions: const FileOptions(
                  contentType: 'image/jpeg', upsert: true));
      // Adiciona cache-buster para forçar reload da imagem
      final url = Supabase.instance.client.storage
              .from('avatars')
              .getPublicUrl(path) +
          '?t=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      await context.read<ProfileViewModel>().updateProfile(avatarUrl: url);
      if (mounted) context.showSnack('Foto de perfil atualizada!');
    } catch (_) {
      if (mounted) {
        context.showSnack('Erro ao atualizar foto. Tente novamente.');
      }
    }
  }

  Future<void> _save() async {
    final vm = context.read<ProfileViewModel>();
    final ok = await vm.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
    );
    if (ok && mounted) {
      context.showSnack('Perfil atualizado!');
      context.pop();
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
                    Text('EDITAR PERFIL',
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

                  // ── Foto de perfil ────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor:
                                    AppColors.navy.withOpacity(0.1),
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
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: AppColors.navy,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.edit,
                                      size: 14, color: Colors.white),
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

                  // ── Nome ──────────────────────────────────────
                  _FieldLabel('NOME'),
                  _InputField(controller: _nameCtrl, hint: 'Seu nome'),
                  const SizedBox(height: 20),

                  // ── Biografia ─────────────────────────────────
                  _FieldLabel('BIOGRAFIA'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _bioCtrl,
                      maxLines: 5,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Conte sobre você...',
                        hintStyle: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Cidade e Estado ───────────────────────────
                  _FieldLabel('CIDADE E ESTADO QUE RESIDE'),
                  _InputField(
                      controller: _cityCtrl,
                      hint: 'Ex: Florianópolis, SC'),
                  const SizedBox(height: 28),

                  // ── Preferências ──────────────────────────────
                  _FieldLabel('PREFERÊNCIAS'),
                  const SizedBox(height: 12),

                  Text('Tipo de rota preferida',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  _DropdownField(
                    hint: 'Selecionar',
                    value: _selectedRouteType,
                    items: _routeTypes,
                    onChanged: (v) =>
                        setState(() => _selectedRouteType = v),
                  ),
                  const SizedBox(height: 20),

                  Text('Paradas de interesse',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),

                  ..._tagCategories.entries.map((entry) => Column(
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
                                .map((tag) => _TagChip(
                                      label: tag,
                                      selected: _selectedTags.contains(tag),
                                      onTap: () => setState(() {
                                        if (_selectedTags.contains(tag)) {
                                          _selectedTags.remove(tag);
                                        } else {
                                          _selectedTags.add(tag);
                                        }
                                      }),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

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
  const _InputField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
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

class _DropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.navy),
          style: AppTextStyles.bodyMedium,
          items: items
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TagChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.transparent,
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.divider,
              width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
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
