import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/club_model.dart';
import '../models/user_model.dart';

/// Acesso aos motoclubes: cadastro, membros/convites e descoberta.
/// O dono é inserido como membro (owner/active) por trigger no banco.
class SupabaseClubService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Criar ──────────────────────────────────────────────────
  static Future<ClubModel> createClub({
    required String name,
    String? description,
    String? city,
    String? stateUf,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    final row = await _db.from('clubs').insert({
      'owner_id': _uid,
      'name': name,
      'description': description,
      'city': city,
      'state_uf': stateUf,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
    }).select().single();
    return ClubModel.fromMap(row,
        myRole: 'owner', myStatus: 'active', membersCount: 1);
  }

  // ── Meus clubes (membro ativo) ─────────────────────────────
  static Future<List<ClubModel>> getMyClubs() async {
    final memberRows = await _db
        .from('club_members')
        .select('club_id, role')
        .eq('user_id', _uid)
        .eq('status', 'active');
    final list = (memberRows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];
    final ids = list.map((r) => r['club_id'] as String).toList();
    final roleById = {
      for (final r in list) r['club_id'] as String: r['role'] as String,
    };
    final clubRows = await _db.from('clubs').select().inFilter('id', ids);
    final counts = await _memberCounts(ids);
    return (clubRows as List).map((c) {
      final id = c['id'] as String;
      return ClubModel.fromMap(c,
          myRole: roleById[id], myStatus: 'active', membersCount: counts[id] ?? 0);
    }).toList();
  }

  // ── Convites pendentes (status invited) ────────────────────
  static Future<List<ClubModel>> getPendingInvites() async {
    final rows = await _db
        .from('club_members')
        .select('club_id')
        .eq('user_id', _uid)
        .eq('status', 'invited');
    final ids =
        (rows as List).map((r) => r['club_id'] as String).toList();
    if (ids.isEmpty) return [];
    final clubRows = await _db.from('clubs').select().inFilter('id', ids);
    return (clubRows as List)
        .map((c) => ClubModel.fromMap(c, myStatus: 'invited', myRole: 'member'))
        .toList();
  }

  // ── Descobrir clubes (que ainda não participo) ─────────────
  static Future<List<ClubModel>> discoverClubs({
    String? stateUf,
    int limit = 30,
  }) async {
    final mine =
        await _db.from('club_members').select('club_id').eq('user_id', _uid);
    final myIds = (mine as List).map((r) => r['club_id'] as String).toSet();

    var q = _db.from('clubs').select();
    if (stateUf != null && stateUf.isNotEmpty) q = q.eq('state_uf', stateUf);
    final rows = await q
        .order('created_at', ascending: false)
        .limit(limit + myIds.length);

    final filtered = (rows as List)
        .cast<Map<String, dynamic>>()
        .where((c) => !myIds.contains(c['id'] as String))
        .take(limit)
        .toList();
    if (filtered.isEmpty) return [];
    final counts =
        await _memberCounts(filtered.map((c) => c['id'] as String).toList());
    return filtered
        .map((c) =>
            ClubModel.fromMap(c, membersCount: counts[c['id'] as String] ?? 0))
        .toList();
  }

  // ── Detalhe ────────────────────────────────────────────────
  static Future<ClubModel?> getClubById(String id) async {
    final row = await _db.from('clubs').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final my = await _db
        .from('club_members')
        .select('role, status')
        .eq('club_id', id)
        .eq('user_id', _uid)
        .maybeSingle();
    final counts = await _memberCounts([id]);
    return ClubModel.fromMap(row,
        myRole: my?['role'] as String?,
        myStatus: my?['status'] as String?,
        membersCount: counts[id] ?? 0);
  }

  // ── Membros ativos (com perfil) ────────────────────────────
  // Desambigua o join: club_members tem 2 FKs para profiles (user_id e
  // invited_by); sem o hint !user_id o PostgREST recusa o embed.
  static Future<List<ClubMemberModel>> getMembers(String clubId) async {
    final rows = await _db
        .from('club_members')
        .select('club_id, user_id, role, status, joined_at, user:profiles!user_id(*)')
        .eq('club_id', clubId)
        .eq('status', 'active');
    return (rows as List)
        .map((r) => ClubMemberModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // ── Convidar / responder convite / sair ────────────────────
  static Future<void> inviteUser(
      String clubId, String userId, String clubName) async {
    await _db.from('club_members').insert({
      'club_id': clubId,
      'user_id': userId,
      'role': 'member',
      'status': 'invited',
      'invited_by': _uid,
    });
    try {
      await _db.from('notifications').insert({
        'user_id': userId,
        'type': 'club_invite',
        'title': 'Convite de motoclube',
        'body': 'Você foi convidado para o motoclube "$clubName".',
        'data': {'clubId': clubId},
      });
    } catch (_) {
      // best-effort: convite continua válido mesmo se a notificação falhar
    }
  }

  static Future<void> acceptInvite(String clubId) async {
    await _db
        .from('club_members')
        .update({'status': 'active'})
        .eq('club_id', clubId)
        .eq('user_id', _uid);
  }

  static Future<void> declineInvite(String clubId) => _removeSelf(clubId);
  static Future<void> leaveClub(String clubId) => _removeSelf(clubId);

  static Future<void> _removeSelf(String clubId) async {
    await _db
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', _uid);
  }

  static Future<void> removeMember(String clubId, String userId) async {
    await _db
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', userId);
  }

  static Future<void> setRole(
      String clubId, String userId, String role) async {
    await _db
        .from('club_members')
        .update({'role': role})
        .eq('club_id', clubId)
        .eq('user_id', userId);
  }

  // ── Editar / apagar ────────────────────────────────────────
  static Future<ClubModel?> updateClub(
    String id, {
    String? name,
    String? description,
    String? city,
    String? stateUf,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (city != null) updates['city'] = city;
    if (stateUf != null) updates['state_uf'] = stateUf;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bannerUrl != null) updates['banner_url'] = bannerUrl;
    if (updates.isNotEmpty) {
      await _db.from('clubs').update(updates).eq('id', id);
    }
    return getClubById(id);
  }

  static Future<void> deleteClub(String id) async {
    await _db.from('clubs').delete().eq('id', id);
  }

  // ── Buscar usuários pra convidar ───────────────────────────
  static Future<List<UserModel>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final rows = await _db
        .from('profiles')
        .select()
        .or('name.ilike.%$q%,username.ilike.%$q%')
        .neq('id', _uid)
        .limit(15);
    return (rows as List).map((r) => UserModel.fromMap(r)).toList();
  }

  // ── Helper: contagem de membros ativos por clube ───────────
  static Future<Map<String, int>> _memberCounts(List<String> clubIds) async {
    if (clubIds.isEmpty) return {};
    final rows = await _db
        .from('club_members')
        .select('club_id')
        .inFilter('club_id', clubIds)
        .eq('status', 'active');
    final map = <String, int>{};
    for (final r in rows as List) {
      final id = r['club_id'] as String;
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }
}
