import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

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
      } else {
        _state = AuthState.unauthenticated;
      }
    } catch (_) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
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

  Future<bool> register(String name, String email, String password) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await SupabaseAuthService.register(name, email, password);
      if (_user != null) {
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      }
      _error = 'Erro ao criar conta';
      _state = AuthState.error;
    } catch (e) {
      _error = _friendlyError(e.toString());
      _state = AuthState.error;
    }
    notifyListeners();
    return false;
  }

  Future<bool> loginWithGoogle(String webClientId) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();
    try {
      _user = await SupabaseAuthService.signInWithGoogle(webClientId);
      if (_user != null) {
        _state = AuthState.authenticated;
        notifyListeners();
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
    if (msg.contains('Invalid login credentials')) return 'Email ou senha incorretos';
    if (msg.contains('Email not confirmed')) return 'Confirme seu email antes de entrar';
    if (msg.contains('User already registered')) return 'Este email já está cadastrado';
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
