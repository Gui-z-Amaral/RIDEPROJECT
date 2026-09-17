import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../constants/app_links.dart';

class SupabaseAuthService {
  static SupabaseClient get _db => Supabase.instance.client;

  // ── Auth state ─────────────────────────────────────────────
  static User? get currentAuthUser => _db.auth.currentUser;
  static bool get isAuthenticated => currentAuthUser != null;

  static Stream<AuthState> get authStateChanges =>
      _db.auth.onAuthStateChange;

  // ── Login ──────────────────────────────────────────────────
  static Future<UserModel?> login(String email, String password) async {
    final res = await _db.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (res.user == null) return null;
    return _profileAfterAuth(res.user!.id);
  }

  // ── Register ───────────────────────────────────────────────
  /// Cadastra o usuário. Quando a confirmação de email está ligada no GoTrue,
  /// o signUp cria o usuário mas NÃO devolve sessão — o GoTrue envia um código
  /// por email e o fluxo continua em [verifySignupCode]. Nesse caso retorna
  /// `needsConfirmation: true` (e user null).
  static Future<({UserModel? user, bool needsConfirmation})> register(
      String name, String email, String password, {String? username}) async {
    final u = username ?? _usernameFrom(name);
    final res = await _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name, 'username': u},
    );
    if (res.user == null) return (user: null, needsConfirmation: false);

    if (res.session == null) {
      // Confirmação de email ligada: o profile já foi criado pelo trigger
      // handle_new_user; a sessão vem depois do verifyOTP.
      return (user: null, needsConfirmation: true);
    }

    // O trigger handle_new_user já criou o profile a partir dos metadados.
    // O upsert abaixo é só defesa em profundidade caso o trigger não tenha
    // rodado por algum motivo; se falhar não vamos quebrar o cadastro inteiro.
    try {
      await _db.from('profiles').upsert({
        'id': res.user!.id,
        'name': name,
        'username': u,
      });
    } catch (e) {
      debugPrint('register: upsert profile fallback falhou (ok se o trigger criou): $e');
    }

    return (user: await _fetchProfile(res.user!.id), needsConfirmation: false);
  }

  // ── Confirmação de email por código (OTP) ──────────────────
  /// Verifica o código de 6 dígitos enviado por email no cadastro.
  /// Sucesso cria a sessão (o listener de auth cuida do resto).
  static Future<UserModel?> verifySignupCode(String email, String code) async {
    final res = await _db.auth.verifyOTP(
      type: OtpType.signup,
      email: email.trim(),
      token: code.trim(),
    );
    if (res.user == null) return null;
    return _profileAfterAuth(res.user!.id);
  }

  /// Reenvia o código de confirmação do cadastro.
  static Future<void> resendSignupCode(String email) async {
    await _db.auth.resend(type: OtpType.signup, email: email.trim());
  }

  // ── Redefinição de senha por código (OTP) ──────────────────
  /// Envia o código de recuperação para o email (esqueci a senha / trocar senha).
  static Future<void> sendRecoveryCode(String email) async {
    await _db.auth.resetPasswordForEmail(email.trim());
  }

  /// Verifica o código de recuperação. Sucesso cria uma sessão temporária que
  /// permite [updatePassword] em seguida.
  static Future<bool> verifyRecoveryCode(String email, String code) async {
    final res = await _db.auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: code.trim(),
    );
    return res.session != null;
  }

  /// Define a nova senha do usuário logado (após verifyRecoveryCode, ou a
  /// qualquer momento com sessão válida).
  static Future<void> updatePassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  // ── Google Sign-In ─────────────────────────────────────────
  // webClientId: ID do cliente Web criado no Google Cloud Console
  /// [returnTo]: caminho interno para onde voltar depois de entrar (ex.:
  /// `/v/<id>`). Só tem efeito na web — no nativo não há redirect de página.
  static Future<UserModel?> signInWithGoogle(
    String webClientId, {
    String? returnTo,
  }) async {
    // Na web o google_sign_in não suporta signIn() interativo (dá assertion).
    // Usamos o OAuth do Supabase: redireciona pro Google e volta pra URL que
    // passarmos; a sessão é recuperada e o listener de authStateChanges assume.
    if (kIsWeb) {
      await _db.auth.signInWithOAuth(
        OAuthProvider.google,
        // Antes era só `Uri.base.origin`, que descartava o caminho: quem vinha
        // do link de uma viagem entrava e caía na home.
        redirectTo: AppLinks.oauthReturnUrl(Uri.base.origin, returnTo),
      );
      return null; // fluxo continua após o redirect de volta
    }

    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // usuário cancelou

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null || accessToken == null) return null;

    final res = await _db.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    if (res.user == null) return null;

    // Garante que o perfil existe (cria se ainda não foi criado pelo trigger)
    final existing = await _fetchProfile(res.user!.id);
    if (existing == null) {
      final name = googleUser.displayName ?? googleUser.email.split('@').first;
      await _db.from('profiles').upsert({
        'id': res.user!.id,
        'name': name,
        'username': _usernameFrom(name),
        'avatar_url': googleUser.photoUrl,
      });
    }

    return _profileAfterAuth(res.user!.id);
  }

  // ── Desativação de conta (LGPD) ────────────────────────────
  /// Desliga a conta do usuário logado, sem apagar nada.
  ///
  /// A lei brasileira exige guardar os dados por pelo menos 6 meses. A função
  /// no banco (migration 034) move os dados pessoais para uma tabela que
  /// ninguém consegue ler pela API e deixa o perfil como "Usuário inativo":
  /// sem foto, sem bio, fora da busca por proximidade e sem push.
  ///
  /// Chame [logout] logo depois — a sessão continua válida até sair.
  static Future<void> deactivateAccount() async {
    await _db.rpc('deactivate_my_account');
  }

  /// Traz a conta de volta com os dados de antes. Chamada no login quando o
  /// perfil está marcado como desativado.
  static Future<void> reactivateAccount() async {
    await _db.rpc('reactivate_my_account');
  }

  // ── Logout ─────────────────────────────────────────────────
  static Future<void> logout() async {
    await _db.auth.signOut();
  }

  // ── Presença (online/offline) ──────────────────────────────
  /// Marca o usuário logado como online/offline em profiles.is_online.
  /// Best-effort: não propaga erro (chamado em lifecycle/login/logout).
  static Future<void> setOnline(bool online) async {
    final u = currentAuthUser;
    if (u == null) return;
    try {
      await _db.from('profiles').update({'is_online': online}).eq('id', u.id);
    } catch (_) {}
  }

  // ── Get current user profile ───────────────────────────────
  static Future<UserModel?> getCurrentUser() async {
    final u = currentAuthUser;
    if (u == null) return null;
    return _fetchProfile(u.id);
  }

  // ── Update profile ─────────────────────────────────────────
  static Future<UserModel?> addPhoto(String url) async {
    final u = currentAuthUser;
    if (u == null) return null;
    final profile = await _fetchProfile(u.id);
    final updated = [...(profile?.photos ?? []), url];
    await _db.from('profiles').update({'photos': updated}).eq('id', u.id);
    return _fetchProfile(u.id);
  }

  static Future<UserModel?> updateProfile({
    String? name,
    String? bio,
    String? city,
    String? motoModel,
    String? motoYear,
    String? avatarUrl,
    String? accountType,
    Object? tripStyle = _unset, // null = limpa, _unset = não tocar
    // ── Business ──
    String? businessName,
    String? businessDescription,
    String? businessBannerUrl,
    String? businessAddressStreet,
    String? businessAddressNumber,
    String? businessAddressNeighborhood,
    String? businessAddressCity,
    String? businessAddressState,
    List<String>? businessCategories,
  }) async {
    final u = currentAuthUser;
    if (u == null) return null;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (bio != null) updates['bio'] = bio;
    if (city != null) updates['city'] = city;
    if (motoModel != null) updates['moto_model'] = motoModel;
    if (motoYear != null) updates['moto_year'] = motoYear;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (accountType != null) updates['account_type'] = accountType;
    if (tripStyle != _unset) updates['trip_style'] = tripStyle;
    if (businessName != null) updates['business_name'] = businessName;
    if (businessDescription != null) {
      updates['business_description'] = businessDescription;
    }
    if (businessBannerUrl != null) {
      updates['business_banner_url'] = businessBannerUrl;
    }
    if (businessAddressStreet != null) {
      updates['business_address_street'] = businessAddressStreet;
    }
    if (businessAddressNumber != null) {
      updates['business_address_number'] = businessAddressNumber;
    }
    if (businessAddressNeighborhood != null) {
      updates['business_address_neighborhood'] = businessAddressNeighborhood;
    }
    if (businessAddressCity != null) {
      updates['business_address_city'] = businessAddressCity;
    }
    if (businessAddressState != null) {
      updates['business_address_state'] = businessAddressState;
    }
    if (businessCategories != null) {
      updates['business_categories'] = businessCategories;
    }
    if (updates.isEmpty) return getCurrentUser();

    await _updateWithRetry(u.id, updates);
    return _fetchProfile(u.id);
  }

  /// Tenta fazer o update; se o Supabase retornar "coluna não encontrada"
  /// (PGRST204), remove a coluna do payload e tenta de novo.
  /// Evita perder o save inteiro só porque uma coluna nova ainda não foi
  /// criada no banco.
  static Future<void> _updateWithRetry(
      String id, Map<String, dynamic> updates) async {
    var payload = Map<String, dynamic>.from(updates);
    while (payload.isNotEmpty) {
      try {
        await _db.from('profiles').update(payload).eq('id', id);
        return;
      } on PostgrestException catch (e) {
        final missing = extractMissingColumn(e);
        if (missing != null && payload.containsKey(missing)) {
          payload.remove(missing);
          continue;
        }
        rethrow;
      }
    }
  }

  /// Extrai o nome da coluna de mensagens como
  /// "Could not find the 'city' column of 'profiles' in the schema cache".
  /// Retorna `null` se o erro não for de coluna ausente (código ≠ PGRST204)
  /// ou se a mensagem não vier no formato esperado.
  @visibleForTesting
  static String? extractMissingColumn(PostgrestException e) {
    if (e.code != 'PGRST204') return null;
    final match = RegExp(r"'([^']+)' column").firstMatch(e.message);
    return match?.group(1);
  }

  // Sentinel para distinguir "não alterar" vs "setar para null".
  static const _unset = Object();

  // ── Helpers ────────────────────────────────────────────────
  /// Perfil de quem acabou de autenticar, reativando a conta se ela estava
  /// desativada.
  ///
  /// Só nos caminhos de LOGIN, e não dentro de _fetchProfile: aquele também
  /// carrega o perfil de outras pessoas, e ressuscitaria a conta no intervalo
  /// entre desativar e sair.
  static Future<UserModel?> _profileAfterAuth(String id) async {
    final profile = await _fetchProfile(id);
    if (profile == null || profile.deactivatedAt == null) return profile;
    await _db.rpc('reactivate_my_account');
    return _fetchProfile(id);
  }

  static Future<UserModel?> _fetchProfile(String id) async {
    final row = await _db
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return UserModel.fromMap(row);
  }

  /// Busca o perfil completo de [id] (dados atuais, incl. flags de privacidade).
  static Future<UserModel?> getProfileById(String id) => _fetchProfile(id);

  static String _usernameFrom(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
