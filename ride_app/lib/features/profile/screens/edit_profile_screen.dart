import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/app_avatar.dart';
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
  late TextEditingController _motoCtrl;
  late TextEditingController _yearCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<ProfileViewModel>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _bioCtrl = TextEditingController(text: user?.bio ?? '');
    _motoCtrl = TextEditingController(text: user?.motoModel ?? '');
    _yearCtrl = TextEditingController(text: user?.motoYear ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _motoCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final vm = context.read<ProfileViewModel>();
    final ok = await vm.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      motoModel: _motoCtrl.text.trim(),
      motoYear: _yearCtrl.text.trim(),
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
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  AppAvatar(imageUrl: user?.avatarUrl, name: user?.name ?? '', size: AppSpacing.avatarXl, borderColor: AppColors.teal),
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.teal, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: AppColors.deepNavy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppInput(controller: _nameCtrl, label: 'Nome', hint: 'Seu nome'),
            const SizedBox(height: AppSpacing.lg),
            AppInput(controller: _bioCtrl, label: 'Biografia', hint: 'Conte sobre você e sua moto...', maxLines: 3),
            const SizedBox(height: AppSpacing.lg),
            AppInput(controller: _motoCtrl, label: 'Modelo da moto', hint: 'Ex: Honda CB 500F', prefixIcon: Icons.motorcycle),
            const SizedBox(height: AppSpacing.lg),
            AppInput(controller: _yearCtrl, label: 'Ano', hint: '2022', keyboardType: TextInputType.number),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(label: 'Salvar alterações', isLoading: vm.isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
