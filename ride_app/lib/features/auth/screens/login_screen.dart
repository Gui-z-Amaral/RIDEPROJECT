import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/constants/supabase_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  bool _stayConnected = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final ok = await vm.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) {
      context.go('/home');
    } else if (mounted && vm.error != null) {
      context.showSnack(vm.error!, isError: true);
    }
  }

  Future<void> _loginWithGoogle() async {
    final vm = context.read<AuthViewModel>();
    final ok = await vm.loginWithGoogle(SupabaseConfig.googleWebClientId);
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
                const SizedBox(height: 48),

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

                const SizedBox(height: 48),

                // Email / username field
                _Field(
                  controller: _emailCtrl,
                  hint: 'Nome de usuário ou email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o email' : null,
                ),
                const SizedBox(height: 12),

                // Password field
                _Field(
                  controller: _passCtrl,
                  hint: 'Senha',
                  obscure: _obscure,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure ? Icons.remove_red_eye_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe a senha' : null,
                ),

                const SizedBox(height: 10),

                // Lembrar-me + Esqueci senha
                Row(
                  children: [
                    _CheckRow(
                      value: _rememberMe,
                      label: 'Lembrar-me',
                      onChanged: (v) => setState(() => _rememberMe = v),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'Esqueci minha senha',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Permanecer conectado
                Align(
                  alignment: Alignment.center,
                  child: _CheckRow(
                    value: _stayConnected,
                    label: 'Permanecer conectado?',
                    onChanged: (v) => setState(() => _stayConnected = v),
                  ),
                ),

                const SizedBox(height: 24),

                // LOGIN button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : _login,
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('LOGIN',
                            style: AppTextStyles.labelLarge),
                  ),
                ),

                const SizedBox(height: 16),

                // Divider ou
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.divider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ou',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                    const Expanded(child: Divider(color: AppColors.divider)),
                  ],
                ),

                const SizedBox(height: 16),

                // Botão Google
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: loading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 2)
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                color: Color(0xFF4285F4),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Continuar com Google',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'Não possui conta ainda?',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),

                // CADASTRE-SE button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('CADASTRE-SE',
                        style: AppTextStyles.labelLarge),
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

// ─── Shared widgets ────────────────────────────────────────────────────────

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

class _CheckRow extends StatelessWidget {
  final bool value;
  final String label;
  final void Function(bool) onChanged;

  const _CheckRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
