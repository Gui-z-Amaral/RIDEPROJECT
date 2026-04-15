import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/utils/extensions.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (ok && mounted) {
      context.go('/home');
    } else if (mounted && vm.error != null) {
      context.showSnack(vm.error!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final loading = vm.state == AuthState.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: AppColors.navy, size: 22),
                    onPressed: () => context.go('/login'),
                    padding: EdgeInsets.zero,
                  ),
                ),

                const SizedBox(height: 12),

                // Logo
                Text(
                  'RIDE',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 40),

                // Nome de usuário
                _Field(
                  controller: _nameCtrl,
                  hint: 'Nome de usuário',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 12),

                // Email
                _Field(
                  controller: _emailCtrl,
                  hint: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o email' : null,
                ),
                const SizedBox(height: 12),

                // Senha
                _Field(
                  controller: _passCtrl,
                  hint: 'Senha',
                  obscure: _obscurePass,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscurePass = !_obscurePass),
                    child: Icon(
                      _obscurePass
                          ? Icons.remove_red_eye_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                const SizedBox(height: 12),

                // Confirmar senha
                _Field(
                  controller: _confirmCtrl,
                  hint: 'Confirme a sua senha',
                  obscure: _obscureConfirm,
                  suffix: GestureDetector(
                    onTap: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Icon(
                      _obscureConfirm
                          ? Icons.remove_red_eye_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  validator: (v) => v != _passCtrl.text
                      ? 'As senhas não conferem'
                      : null,
                ),

                const SizedBox(height: 28),

                // CADASTRAR button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : _register,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('CADASTRAR',
                            style: AppTextStyles.labelLarge),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Já possui conta?',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),

                // LOGIN button (outlined)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'LOGIN',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.navy),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                Text(
                  'Travelly All Rights Reserved',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared field widget ───────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffix,
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}
