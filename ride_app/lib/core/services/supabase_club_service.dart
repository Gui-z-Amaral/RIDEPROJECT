import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/club_model.dart';
import '../models/user_model.dart';
import '../models/club_invite.dart';

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
  static Future<List<ClubModel>> getMyClubs() => getClubsOf(_uid);

  /// Motoclubes de [userId] — usado no perfil de outra pessoa.
  ///
  /// Mesmo caminho do [getMyClubs]: `club_members` já é legível por qualquer
  /// usuário (policy `club_members_select`), então listar o clube de alguém
  /// não abre nada que já não estivesse aberto.
  static Future<List<ClubModel>> getClubsOf(String userId) async {
    final memberRows = await _db
        .from('club_members')
        .select('club_id, role')
        .eq('user_id', userId)
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
        .select('club_id, user_id, role, status, joined_at, user:profiles!user_id(*, profile_details(*))')
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
  /// Salva as alterações. NÃO relê o clube de propósito: juntar as duas coisas
  /// fazia uma falha de leitura virar "não foi possível salvar" numa tela em
  /// que o dado já tinha sido gravado. Quem precisa do modelo novo chama
  /// [getClubById] em seguida.
  static Future<void> updateClub(
    String id, {
    String? name,
    String? description,
    String? city,
    String? stateUf,
    String? avatarUrl,
    String? bannerUrl,
    bool? eventsPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (city != null) updates['city'] = city;
    if (stateUf != null) updates['state_uf'] = stateUf;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bannerUrl != null) updates['banner_url'] = bannerUrl;
    if (eventsPublic != null) updates['events_public'] = eventsPublic;
    if (updates.isEmpty) return;
    await _db.from('clubs').update(updates).eq('id', id);
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
        .select(UserModel.dbColumns)
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

  // ── Convites por link (migration 038) ──────────────────────
  // Tudo passa por funcoes no banco: a tabela club_invites nao e acessivel
  // pela API. Sem isso, qualquer pessoa logada listaria os tokens de todos os
  // clubes e entraria em qualquer um.

  /// Cria um convite e devolve o token. So administradores.
  static Future<String> createInvite(
      String clubId, ClubInviteKind kind) async {
    final token = await _db.rpc('club_invite_create', params: {
      'p_club_id': clubId,
      'p_kind': kind.code,
    });
    return token as String;
  }

  /// O que mostrar para quem recebeu o link. Funciona sem estar logado — a
  /// pessoa precisa ver de qual clube e o convite ANTES de criar conta.
  static Future<ClubInvitePreview> previewInvite(String token) async {
    try {
      final rows = await _db.rpc('club_invite_preview', params: {
        'p_token': token,
      });
      final list = rows as List;
      if (list.isEmpty) return const ClubInvitePreview();
      return ClubInvitePreview.fromMap(
          Map<String, dynamic>.from(list.first as Map));
    } catch (_) {
      return const ClubInvitePreview();
    }
  }

  /// Aceita o convite POR LINK. Nao confundir com [acceptInvite], que e do
  /// convite direto (a pessoa ja aparece como 'invited' no clube).
  ///
  /// O servidor decide: 'entrou', 'ja_membro', 'usado', 'expirado',
  /// 'revogado', 'invalido' ou 'sem_sessao'.
  static Future<String> acceptInviteLink(String token) async {
    try {
      final r = await _db.rpc('club_invite_accept', params: {
        'p_token': token,
      });
      return (r as String?) ?? 'invalido';
    } catch (_) {
      return 'invalido';
    }
  }

  /// Convites ativos do clube. So administradores.
  static Future<List<ClubInvite>> listInvites(String clubId) async {
    final rows = await _db.rpc('club_invites_list', params: {
      'p_club_id': clubId,
    });
    return (rows as List)
        .map((r) => ClubInvite.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Derruba um convite. Vale inclusive para o permanente — sem isso ele seria
  /// uma porta que nunca fecha.
  static Future<void> revokeInvite(String token) async {
    await _db.rpc('club_invite_revoke', params: {'p_token': token});
  }
}
