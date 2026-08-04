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

/// Confirmação de email pós-cadastro: o usuário digita o código de 6 dígitos
/// recebido por email. Sucesso = sessão criada → home.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeCtrl = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldown = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeCtrl.dispose();
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

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (!isValidOtpCode(code)) {
      context.showSnack('Digite o código de 6 dígitos', isError: true);
      return;
    }
    final vm = context.read<AuthViewModel>();
    final ok = await vm.verifySignupCode(widget.email, code);
    if (!mounted) return;
    if (ok) {
      context.showSnack('Email confirmado. Bem-vindo!');
      context.go('/home');
    } else {
      context.showSnack(vm.error ?? 'Código inválido', isError: true);
    }
  }

  Future<void> _resend() async {
    final vm = context.read<AuthViewModel>();
    final err = await vm.resendSignupCode(widget.email);
    if (!mounted) return;
    if (err == null) {
      _startCooldown();
      context.showSnack('Código reenviado para ${widget.email}');
    } else {
      context.showSnack(err, isError: true);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios,
                      color: AppColors.navy, size: 22),
                  onPressed: () => context.go('/login'),
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
                child: Icon(Icons.mark_email_read_outlined,
                    color: AppColors.navy, size: 34),
              ),
              const SizedBox(height: 20),
              Text('CONFIRME SEU EMAIL',
                  style: AppTextStyles.headlineLarge
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'Enviamos um código de 6 dígitos para\n${widget.email}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Campo do código
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
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : _verify,
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text('CONFIRMAR', style: AppTextStyles.labelLarge),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: (_cooldown > 0 || loading) ? null : _resend,
                child: Text(
                  _cooldown > 0
                      ? 'Reenviar código em ${_cooldown}s'
                      : 'Reenviar código',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _cooldown > 0 ? AppColors.textMuted : AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
