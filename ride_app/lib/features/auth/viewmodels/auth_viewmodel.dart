import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/chat_key_service.dart';
import '../../../core/utils/db_errors.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

/// Resultado do cadastro: sucesso direto, aguardando código de email, ou falha.
enum RegisterOutcome { success, needsConfirmation, failed }

class AuthViewModel extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _error;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;

  AuthViewModel() {
    _init();
  }

  void _init() {
    SupabaseAuthService.authStateChanges.listen((data) async {
      if (data.session != null) {
        _user = await SupabaseAuthService.getCurrentUser();
        _state = AuthState.authenticated;
      } else {
        _user = null;
        _state = AuthState.unauthenticated;
      }
      notifyListeners();
    });
    _checkCurrentSession();
  }

  Future<void> _checkCurrentSession() async {
    _state = AuthState.loading;
    notifyListeners();
    try {
      if (SupabaseAuthService.isAuthenticated) {
        _user = await SupabaseAuthService.getCurrentUser()
            .timeout(const Duration(seconds: 8));
        _state = _user != null ? AuthState.authenticated : AuthState.unauthenticated;
        if (_user != null) {
          // App reaberto já logado → garante chaves E2EE.
          ChatKeyService.ensureKeys();
        }
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  /// Pós-autenticação (qualquer caminho: senha, Google ou código de email):
  /// registra push, marca online e garante as chaves E2EE. Idempotente.
  void _onAuthenticated() {
    PushNotificationService.instance.registerForCurrentUser();
    SupabaseAuthService.setOnline(true);
    ChatKeyService.ensureKeys();
  }

  Future<bool> login(String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await SupabaseAuthService.login(email, password);
      if (_user != null) {
        _state = AuthState.authenticated;
        notifyListeners();
        _onAuthenticated();
        return true;
      }
      _error = 'Credenciais inválidas';
      _state = AuthState.error;
    } catch (e) {
      _error = _friendlyError(e.toString());
      _state = AuthState.error;
    }
    notifyListeners();
    return false;
  }

  Future<RegisterOutcome> register(
      String name, String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      // Confere o nome antes de criar a conta: se o trigger recusar, o GoTrue
      // só devolve "Database error saving new user" e a pessoa não saberia o
      // que corrigir. Falha de rede aqui não bloqueia — a regra continua
      // valendo no banco.
      String? problema;
      try {
        problema = await SupabaseAuthService.checkText('nome', name);
      } catch (_) {}
      if (problema != null) {
        _error = DbErrors.textoMensagem(problema, 'nome');
        _state = AuthState.error;
        notifyListeners();
        return RegisterOutcome.failed;
      }

      final res = await SupabaseAuthService.register(name, email, password);
      if (res.needsConfirmation) {
        // Código enviado por email — tela de cadastro navega pra verificação.
        _state = AuthState.unauthenticated;
        notifyListeners();
        return RegisterOutcome.needsConfirmation;
      }
      if (res.user != null) {
        _user = res.user;
        _state = AuthState.authenticated;
        notifyListeners();
        _onAuthenticated();
        return RegisterOutcome.success;
      }
      _error = 'Erro ao criar conta';
      _state = AuthState.error;
    } catch (e) {
      debugPrint('AuthViewModel.register: $e');
      _error = _friendlyError(e.toString());
      _state = AuthState.error;
    }
    notifyListeners();
    return RegisterOutcome.failed;
  }

  /// Confirma o código de 6 dígitos do cadastro. Sucesso = logado.
  Future<bool> verifySignupCode(String email, String code) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await SupabaseAuthService.verifySignupCode(email, code);
      if (_user != null) {
        _state = AuthState.authenticated;
        notifyListeners();
        _onAuthenticated();
        return true;
      }
      _error = 'Código inválido ou expirado';
      _state = AuthState.error;
    } catch (e) {
      debugPrint('AuthViewModel.verifySignupCode: $e');
      _error = _friendlyError(e.toString());
      _state = AuthState.error;
    }
    notifyListeners();
    return false;
  }

  /// Reenvia o código de confirmação do cadastro. Retorna erro amigável ou null.
  Future<String?> resendSignupCode(String email) async {
    try {
      await SupabaseAuthService.resendSignupCode(email);
      return null;
    } catch (e) {
      return _friendlyError(e.toString());
    }
  }

  // ── Redefinição de senha por código ─────────────────────────
  /// Envia o código de recuperação. Retorna erro amigável ou null.
  Future<String?> sendRecoveryCode(String email) async {
    try {
      await SupabaseAuthService.sendRecoveryCode(email);
      return null;
    } catch (e) {
      return _friendlyError(e.toString());
    }
  }

  /// Verifica o código e define a nova senha. Retorna erro amigável ou null.
  Future<String?> confirmPasswordReset(
      String email, String code, String newPassword) async {
    try {
      final ok = await SupabaseAuthService.verifyRecoveryCode(email, code);
      if (!ok) return 'Código inválido ou expirado';
      await SupabaseAuthService.updatePassword(newPassword);
      // O verifyOTP criou sessão — o listener de authState já atualiza o app.
      return null;
    } catch (e) {
      debugPrint('AuthViewModel.confirmPasswordReset: $e');
      return _friendlyError(e.toString());
    }
  }

  /// [returnTo]: caminho para onde voltar depois de entrar, quando a pessoa
  /// chegou por um link compartilhado. Na web o Google recarrega a pagina
  /// inteira, entao o destino precisa ir junto no redirect.
  Future<bool> loginWithGoogle(String webClientId, {String? returnTo}) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      // Na web isso dispara um redirect de página; a volta é tratada pelo
      // listener de authStateChanges. Não há usuário para retornar aqui.
      if (kIsWeb) {
        await SupabaseAuthService.signInWithGoogle(webClientId, returnTo: returnTo);
        return true;
      }
      _user = await SupabaseAuthService.signInWithGoogle(webClientId, returnTo: returnTo);
      if (_user != null) {
        _state = AuthState.authenticated;
        notifyListeners();
        _onAuthenticated();
        return true;
      }
      // signInWithGoogle retornou null (idToken ou accessToken veio vazio)
      _error = 'Google: token nulo. Verifique o serverClientId e o cliente Android no Google Cloud Console.';
      _state = AuthState.error;
    } catch (e) {
      // Mostra o erro técnico para diagnóstico
      _error = e.toString().length > 120 ? e.toString().substring(0, 120) : e.toString();
      _state = AuthState.error;
    }
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    // Marca offline e remove o token deste aparelho ANTES do signOut (precisa do uid).
    await SupabaseAuthService.setOnline(false);
    await PushNotificationService.instance.removeForCurrentUser();
    // Apaga a chave do chat deste aparelho. Com await de proposito: sem ele,
    // o proximo usuario a logar no mesmo aparelho poderia encontrar a chave
    // de quem saiu. A chave volta do servidor no proximo login.
    await ChatKeyService.clearCache();
    await SupabaseAuthService.logout();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendlyError(String msg) {
    final texto = DbErrors.textoInvalido(msg);
    if (texto != null) return texto;
    if (msg.contains('Invalid login credentials')) return 'Email ou senha incorretos';
    if (msg.contains('Email not confirmed')) return 'Confirme seu email antes de entrar';
    // Diz o que fazer, não só o que deu errado: o GoTrue vincula identidades
    // pelo email, então quem já entrou com o Google tem conta SEM senha. Só
    // "já está cadastrado" mandava a pessoa tentar uma senha que não existe.
    if (msg.contains('User already registered')) {
      return 'Este email já está cadastrado. Entre pelo login — se você criou '
          'a conta com o Google, use o botão do Google.';
    }
    if (msg.contains('Confirme seu email para entrar')) {
      return 'Confirme seu email para entrar. Cheque sua caixa de entrada.';
    }
    if (msg.contains('Signups not allowed') ||
        msg.contains('Email signups are disabled') ||
        msg.contains('signup_disabled')) {
      return 'Cadastro por email está desativado no servidor.';
    }
    if (msg.contains('Database error saving new user')) {
      // Antes a tela dizia "verifique o trigger handle_new_user" — mensagem de
      // desenvolvedor para quem só quer criar conta.
      return 'Não foi possível criar a conta agora. Tente de novo em instantes.';
    }
    if (msg.contains('Error sending confirmation email')) {
      return 'Servidor não consegue enviar o email de confirmação. '
          'Ative ENABLE_EMAIL_AUTOCONFIRM=true no GoTrue (ou configure SMTP).';
    }
    if (msg.contains('weak_password') || msg.contains('Password should be')) {
      return 'Senha fraca. Use ao menos 6 caracteres.';
    }
    if (msg.contains('invalid_email') || msg.contains('Unable to validate email')) {
      return 'Email inválido.';
    }
    if (msg.contains('over_email_send_rate_limit') ||
        msg.contains('rate limit')) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
    }
    if (msg.contains('Token has expired') ||
        msg.contains('otp_expired') ||
        msg.contains('invalid or has expired')) {
      return 'Código inválido ou expirado. Peça um novo código.';
    }
    if (msg.contains('For security purposes')) {
      return 'Aguarde alguns segundos antes de pedir outro código.';
    }
    if (msg.contains('network')) return 'Sem conexão com a internet';
    // Google Sign-In errors
    if (msg.contains('sign_in_cancelled') || msg.contains('PlatformException(sign_in_canceled')) return 'Login cancelado';
    if (msg.contains('sign_in_failed')) return 'Falha no Google. Verifique se o cliente Android está configurado no Google Cloud Console com o SHA-1 correto.';
    if (msg.contains('network_error')) return 'Sem conexão com a internet';
    if (msg.contains('ApiException: 10')) return 'Google Sign-In não configurado. Adicione o cliente Android com o SHA-1 no Google Cloud Console.';
    if (msg.contains('ApiException: 12500')) return 'Google Play Services desatualizado. Atualize pelo Play Store.';
    if (msg.contains('ApiException: 12501')) return 'Login cancelado pelo usuário';
    return 'Erro inesperado. Tente novamente';
  }
}
