import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

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
    return _fetchProfile(res.user!.id);
  }

  // ── Register ───────────────────────────────────────────────
  static Future<UserModel?> register(
      String name, String email, String password, {String? username}) async {
    final u = username ?? _usernameFrom(name);
    final res = await _db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name, 'username': u},
    );
    if (res.user == null) return null;

    // Upsert profile (trigger already creates it, this ensures fields)
    await _db.from('profiles').upsert({
      'id': res.user!.id,
      'name': name,
      'username': u,
    });

    return _fetchProfile(res.user!.id);
  }

  // ── Google Sign-In ─────────────────────────────────────────
  // webClientId: ID do cliente Web criado no Google Cloud Console
  static Future<UserModel?> signInWithGoogle(String webClientId) async {
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

    return _fetchProfile(res.user!.id);
  }

  // ── Logout ─────────────────────────────────────────────────
  static Future<void> logout() async {
    await _db.auth.signOut();
  }

  // ── Get current user profile ───────────────────────────────
  static Future<UserModel?> getCurrentUser() async {
    final u = currentAuthUser;
    if (u == null) return null;
    return _fetchProfile(u.id);
  }

  // ── Update profile ─────────────────────────────────────────
  static Future<UserModel?> updateProfile({
    String? name,
    String? bio,
    String? city,
    String? motoModel,
    String? motoYear,
    String? avatarUrl,
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
    if (updates.isEmpty) return getCurrentUser();

    await _db.from('profiles').update(updates).eq('id', u.id);
    return _fetchProfile(u.id);
  }

  // ── Helpers ────────────────────────────────────────────────
  static Future<UserModel?> _fetchProfile(String id) async {
    final row = await _db
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return _rowToUser(row);
  }

  static UserModel _rowToUser(Map<String, dynamic> r) => UserModel(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        username: r['username'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String?,
        bio: r['bio'] as String?,
        city: r['city'] as String?,
        motoModel: r['moto_model'] as String?,
        motoYear: r['moto_year'] as String?,
        friendsCount: (r['friends_count'] as num?)?.toInt() ?? 0,
        tripsCount: (r['trips_count'] as num?)?.toInt() ?? 0,
        isOnline: r['is_online'] as bool? ?? false,
        createdAt: r['created_at'] != null
            ? DateTime.parse(r['created_at'] as String)
            : null,
      );

  static String _usernameFrom(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
