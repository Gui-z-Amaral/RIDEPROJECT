import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../models/session_invite.dart';
import '../utils/db_time.dart';
import '../utils/participant_rows.dart';

class SupabaseRideService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar MEUS rolês ──────────────────────────────────────
  // Só rolês que eu criei OU em que aceitei o convite (status confirmed e
  // ainda ativo). Convite não aceito fica só na aba de Convites; recusado/
  // saído (left_at) some da lista.
  static Future<List<RideModel>> getRides() async {
    final created = await _db
        .from('rides')
        .select('id')
        .eq('creator_id', _uid);
    final confirmed = await _db
        .from('ride_participants')
        .select('ride_id')
        .eq('user_id', _uid)
        .eq('status', 'confirmed')
        .isFilter('left_at', null);

    final myRideIds = <String>{
      ...(created as List).map((r) => r['id'] as String),
      ...(confirmed as List).map((r) => r['ride_id'] as String),
    };
    if (myRideIds.isEmpty) return [];

    final rows = await _db
        .from('rides')
        .select('''
          *,
          creator:profiles!rides_creator_id_fkey(*, profile_details(*)),
          participants:ride_participants(user:profiles(*, profile_details(*)), left_at, status, user_id)
        ''')
        .inFilter('id', myRideIds.toList())
        .order('created_at', ascending: false);

    return rows.map(_rowToRide).toList();
  }

  // ── Buscar rolê por ID ─────────────────────────────────────
  static Future<RideModel?> getRideById(String id) async {
    final row = await _db
        .from('rides')
        .select('''
          *,
          creator:profiles!rides_creator_id_fkey(*, profile_details(*)),
          participants:ride_participants(user:profiles(*, profile_details(*)), left_at, status, user_id)
        ''')
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return _rowToRide(row);
  }

  // ── Histórico de rolês do usuário ──────────────────────────
  static Future<List<RideHistoryEntry>> getRideHistory() async {
    final rows = await _db
        .from('ride_participants')
        .select('''
          joined_at, left_at,
          ride:rides!inner(
            id, title, status, started_at, created_at, creator_id,
            meeting_label, meeting_address
          )
        ''')
        .eq('user_id', _uid)
        .order('joined_at', ascending: false);

    return (rows as List).map((r) {
      final ride = r['ride'] as Map<String, dynamic>;
      return RideHistoryEntry(
        rideId: ride['id'] as String,
        title: ride['title'] as String,
        meetingName: (ride['meeting_label'] as String?)?.isNotEmpty == true
            ? ride['meeting_label'] as String
            : (ride['meeting_address'] as String? ?? ''),
        status: _parseStatus(ride['status'] as String?),
        creatorId: ride['creator_id'] as String?,
        startedAt: DbTime.tryParse(ride['started_at']),
        createdAt: DbTime.parse(ride['created_at']),
        joinedAt: DbTime.tryParse(r['joined_at']),
        leftAt: DbTime.tryParse(r['left_at']),
      );
    }).toList();
  }

  // ── Criar rolê ─────────────────────────────────────────────
  static Future<RideModel> createRide({
    required String title,
    required LocationModel meetingPoint,
    List<String> participantIds = const [],
    DateTime? scheduledAt,
    bool isImmediate = false,
  }) async {
    final rideRow = await _db.from('rides').insert({
      'creator_id': _uid,
      'title': title,
      'meeting_lat': meetingPoint.lat,
      'meeting_lng': meetingPoint.lng,
      'meeting_address': meetingPoint.address,
      'meeting_label': meetingPoint.label,
      'scheduled_at': DbTime.toDb(scheduledAt),
      'is_immediate': isImmediate,
    }).select().single();

    final rideId = rideRow['id'] as String;

    // Duas inserções — mesmo motivo da viagem (migration 040): a RLS rejeitava
    // o lote inteiro por causa das linhas de terceiro, e o catch escondia.
    await _db
        .from('ride_participants')
        .insert({'ride_id': rideId, 'user_id': _uid, 'status': 'confirmed'});

    final invited = ParticipantRows.invitedRows(
      fkColumn: 'ride_id',
      parentId: rideId,
      creatorId: _uid,
      participantIds: participantIds,
    );
    if (invited.isNotEmpty) {
      await _db.from('ride_participants').insert(invited);
    }

    // Atualiza rides_count do criador (best-effort — RPC pode não existir)
    try {
      await _db.rpc('update_rides_count', params: {'p_user_id': _uid});
    } catch (_) {}

    return (await getRideById(rideId))!;
  }

  // ── Atualizar status ───────────────────────────────────────
  static Future<void> updateStatus(String rideId, RideStatus status) async {
    final update = <String, dynamic>{'status': status.name};
    if (status == RideStatus.active) {
      update['started_at'] = DbTime.nowForDb();
    }
    await _db
        .from('rides')
        .update(update)
        .eq('id', rideId)
        .eq('creator_id', _uid);
  }

  // ── Entrar / sair do rolê ──────────────────────────────────
  static Future<void> joinRide(String rideId) async {
    await _db.from('ride_participants').upsert({
      'ride_id': rideId,
      'user_id': _uid,
    });
  }

  // ── Convidar novos participantes ───────────────────────────
  static Future<void> inviteParticipants(
      String rideId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    await _db.rpc('invite_ride_participants', params: {
      'p_ride_id': rideId,
      'p_user_ids': userIds,
    });
  }

  static Future<void> leaveRide(String rideId) async {
    // Soft-delete: guarda o timestamp de saída para o histórico
    await _db
        .from('ride_participants')
        .update({'left_at': DbTime.nowForDb()})
        .eq('ride_id', rideId)
        .eq('user_id', _uid);
  }

  /// Remove o rolê do histórico do usuário de forma permanente: apaga a linha
  /// de participação (hard delete). Diferente de [leaveRide] (soft-delete que
  /// mantém o registro no histórico), some de vez do perfil.
  static Future<void> removeFromHistory(String rideId) async {
    await _db
        .from('ride_participants')
        .delete()
        .eq('ride_id', rideId)
        .eq('user_id', _uid);
  }

  // ── Localização em tempo real ──────────────────────────────
  static Future<void> upsertLocation(
      String rideId, double lat, double lng) async {
    await _db.from('ride_locations').upsert({
      'ride_id': rideId,
      'user_id': _uid,
      'lat': lat,
      'lng': lng,
      'updated_at': DbTime.nowForDb(),
    }, onConflict: 'ride_id,user_id');
  }

  static Future<List<Map<String, dynamic>>> getLocations(
      String rideId) async {
    return await _db
        .from('ride_locations')
        .select('user_id, lat, lng')
        .eq('ride_id', rideId);
  }

  // ── Convites pendentes (participação 'waiting', não-criador) ───
  static Future<List<SessionInvite>> getPendingInvites() async {
    final rows = await _db
        .from('ride_participants')
        .select('left_at, ride:rides!inner(id, title, creator_id, scheduled_at)')
        .eq('user_id', _uid)
        .eq('status', 'waiting');

    final out = <SessionInvite>[];
    for (final r in rows as List) {
      if (r['left_at'] != null) continue;
      final ride = r['ride'] as Map<String, dynamic>?;
      if (ride == null || ride['creator_id'] == _uid) continue; // ignora os meus
      out.add(SessionInvite(
        sessionId: ride['id'] as String,
        title: ride['title'] as String? ?? 'Rolê',
        isRide: true,
        scheduledAt: DbTime.tryParse(ride['scheduled_at']),
      ));
    }
    return out;
  }

  // ── Confirmar / recusar participação ──────────────────────
  /// Upsert, não update: um `update` que não encontra linha devolve 204 sem
  /// erro, e era assim que aceitar um convite não fazia nada e ainda mostrava
  /// "Você aceitou!". Com upsert, quem tem convite antigo sem linha (todo
  /// convite criado antes da migration 040) entra ao tocar em aceitar de novo.
  static Future<void> confirmParticipation(String rideId) async {
    await _db.from('ride_participants').upsert({
      'ride_id': rideId,
      'user_id': _uid,
      'status': 'confirmed',
    }, onConflict: 'ride_id,user_id');
  }

  static Future<void> declineParticipation(String rideId) async {
    await _db
        .from('ride_participants')
        .update({'status': 'declined'})
        .eq('ride_id', rideId)
        .eq('user_id', _uid);
  }

  // ── Deletar rolê ───────────────────────────────────────────
  static Future<void> deleteRide(String rideId) async {
    // Remove participantes primeiro (sem CASCADE na FK)
    await _db.from('ride_participants').delete().eq('ride_id', rideId);
    await _db
        .from('rides')
        .delete()
        .eq('id', rideId)
        .eq('creator_id', _uid);
  }

  // ── Helpers ────────────────────────────────────────────────
  static RideModel _rowToRide(Map<String, dynamic> r) {
    final creatorRow = r['creator'] as Map<String, dynamic>? ?? {};
    final participantRows =
        (r['participants'] as List? ?? []).cast<Map<String, dynamic>>();

    return RideModel(
      id: r['id'] as String,
      title: r['title'] as String,
      meetingPoint: LocationModel(
        lat: (r['meeting_lat'] as num).toDouble(),
        lng: (r['meeting_lng'] as num).toDouble(),
        address: r['meeting_address'] as String?,
        label: r['meeting_label'] as String?,
      ),
      creator: UserModel.fromMap(creatorRow),
      // Mostra apenas: criador (sempre) + participantes que aceitaram o convite
      participants: participantRows
          .where((p) =>
              p['left_at'] == null &&
              (p['user_id'] == r['creator_id'] ||
                  p['status'] == 'confirmed'))
          .map((p) => UserModel.fromMap(p['user'] as Map<String, dynamic>? ?? {}))
          .toList(),
      status: _parseStatus(r['status'] as String?),
      scheduledAt: DbTime.tryParse(r['scheduled_at']),
      isImmediate: r['is_immediate'] as bool? ?? false,
      createdAt: DbTime.parse(r['created_at']),
      startedAt: DbTime.tryParse(r['started_at']),
    );
  }

  static RideStatus _parseStatus(String? s) {
    switch (s) {
      case 'waiting':   return RideStatus.waiting;
      case 'active':    return RideStatus.active;
      case 'completed': return RideStatus.completed;
      case 'cancelled': return RideStatus.cancelled;
      default:          return RideStatus.scheduled;
    }
  }
}
