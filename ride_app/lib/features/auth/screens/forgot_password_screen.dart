import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/utils/auth_validators.dart';
import '../../../core/utils/extensions.dart';

/// Redefinição de senha por código: informa o email → recebe código de 6
/// dígitos → digita código + nova senha. Usada tanto no "esqueci a senha"
/// (deslogado, a partir do login) quanto no "trocar senha" (logado, a partir
/// das Configurações — com [initialEmail] pré-preenchido).
class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.initialEmail ?? '');
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _obscure = true;
  Timer? _cooldownTimer;
  int _cooldown = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!looksLikeEmail(email)) {
      context.showSnack('Informe um email válido', isError: true);
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthViewModel>().sendRecoveryCode(email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      setState(() => _codeSent = true);
      _startCooldown();
      context.showSnack('Código enviado para $email');
    } else {
      context.showSnack(err, isError: true);
    }
  }

  Future<void> _confirm() async {
    final code = _codeCtrl.text.trim();
    if (!isValidOtpCode(code)) {
      context.showSnack('Digite o código de 6 dígitos', isError: true);
      return;
    }
    final passErr =
        passwordError(_passCtrl.text, confirm: _confirmCtrl.text);
    if (passErr != null) {
      context.showSnack(passErr, isError: true);
      return;
    }
    setState(() => _busy = true);
    final err = await context.read<AuthViewModel>().confirmPasswordReset(
        _emailCtrl.text.trim(), code, _passCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      context.showSnack('Senha alterada com sucesso!');
      // verifyOTP criou sessão → o usuário já está logado.
      context.go('/home');
    } else {
      context.showSnack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: AppColors.navy, size: 22),
                  onPressed: () => context.pop(),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset,
                    color: AppColors.navy, size: 34),
              ),
              const SizedBox(height: 20),
              Text('REDEFINIR SENHA',
                  style: AppTextStyles.headlineLarge
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Digite o código enviado para\n${_emailCtrl.text.trim()} e a nova senha'
                    : 'Informe seu email para receber\num código de 6 dígitos',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              if (!_codeSent) ...[
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Email'),
                  onSubmitted: (_) => _sendCode(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _sendCode,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('ENVIAR CÓDIGO',
                            style: AppTextStyles.labelLarge),
                  ),
                ),
              ] else ...[
                // Código
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: 12),
                  decoration: const InputDecoration(
                    hintText: '••••••',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                // Nova senha
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nova senha',
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure
                            ? Icons.remove_red_eye_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(hintText: 'Confirme a nova senha'),
                  onSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _confirm,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('ALTERAR SENHA',
                            style: AppTextStyles.labelLarge),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_cooldown > 0 || _busy) ? null : _sendCode,
                  child: Text(
                    _cooldown > 0
                        ? 'Reenviar código em ${_cooldown}s'
                        : 'Reenviar código',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _cooldown > 0
                          ? AppColors.textMuted
                          : AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
