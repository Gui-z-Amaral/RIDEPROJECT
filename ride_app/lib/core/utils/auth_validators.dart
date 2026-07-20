/// Validadores puros dos fluxos de autenticação por código (OTP).
/// Sem dependência de Flutter/Supabase — testáveis isoladamente.

/// `true` se [code] é um código OTP válido do GoTrue (6 dígitos).
bool isValidOtpCode(String code) => RegExp(r'^\d{6}$').hasMatch(code.trim());

/// Valida a nova senha. Retorna a mensagem de erro, ou `null` se ok.
/// Regra igual à do cadastro: mínimo 6 caracteres.
String? passwordError(String password, {String? confirm}) {
  if (password.length < 6) return 'Mínimo 6 caracteres';
  if (confirm != null && confirm != password) return 'As senhas não conferem';
  return null;
}

/// Validação superficial de email (o GoTrue valida de verdade no envio).
bool looksLikeEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
