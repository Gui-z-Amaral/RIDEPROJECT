import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';

class SupabaseRideService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar todos os rolês ──────────────────────────────────
  static Future<List<RideModel>> getRides() async {
    // Só retorna rolês onde o usuário atual é participante ativo (left_at IS NULL)
    final participantRows = await _db
        .from('ride_participants')
        .select('ride_id')
        .eq('user_id', _uid)
        .isFilter('left_at', null);

    final activeRideIds = (participantRows as List)
        .map((r) => r['ride_id'] as String)
        .toList();

    if (activeRideIds.isEmpty) return [];

    final rows = await _db
        .from('rides')
        .select('''
          *,
          creator:profiles!rides_creator_id_fkey(*),
          participants:ride_participants(user:profiles(*), left_at, status, user_id)
        ''')
        .inFilter('id', activeRideIds)
        .order('created_at', ascending: false);

    return rows.map(_rowToRide).toList();
  }

  // ── Buscar rolê por ID ─────────────────────────────────────
  static Future<RideModel?> getRideById(String id) async {
    final row = await _db
        .from('rides')
        .select('''
          *,
          creator:profiles!rides_creator_id_fkey(*),
          participants:ride_participants(user:profiles(*), left_at, status, user_id)
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
            id, title, status, started_at, created_at,
            meeting_label, meeting_address
          )
        ''')
        .eq('user_id', _uid)
        .order('created_at', ascending: false);

    return (rows as List).map((r) {
      final ride = r['ride'] as Map<String, dynamic>;
      return RideHistoryEntry(
        rideId: ride['id'] as String,
        title: ride['title'] as String,
        meetingName: (ride['meeting_label'] as String?)?.isNotEmpty == true
            ? ride['meeting_label'] as String
            : (ride['meeting_address'] as String? ?? ''),
        status: _parseStatus(ride['status'] as String?),
        startedAt: ride['started_at'] != null
            ? DateTime.parse(ride['started_at'] as String)
            : null,
        createdAt: DateTime.parse(ride['created_at'] as String),
        joinedAt: r['joined_at'] != null
            ? DateTime.parse(r['joined_at'] as String)
            : null,
        leftAt: r['left_at'] != null
            ? DateTime.parse(r['left_at'] as String)
            : null,
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
      'scheduled_at': scheduledAt?.toIso8601String(),
      'is_immediate': isImmediate,
    }).select().single();

    final rideId = rideRow['id'] as String;

    // Add creator + invited participants.
    // If batch insert fails (RLS restriction), fall back to creator-only.
    final allParticipants = [_uid, ...participantIds.where((id) => id != _uid)];
    try {
      await _db.from('ride_participants').insert(
        allParticipants.map((id) => {'ride_id': rideId, 'user_id': id}).toList(),
      );
    } catch (_) {
      await _db.from('ride_participants').insert(
        {'ride_id': rideId, 'user_id': _uid},
      );
    }

    return (await getRideById(rideId))!;
  }

  // ── Atualizar status ───────────────────────────────────────
  static Future<void> updateStatus(String rideId, RideStatus status) async {
    final update = <String, dynamic>{'status': status.name};
    if (status == RideStatus.active) {
      update['started_at'] = DateTime.now().toIso8601String();
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
        .update({'left_at': DateTime.now().toIso8601String()})
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
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'ride_id,user_id');
  }

  static Future<List<Map<String, dynamic>>> getLocations(
      String rideId) async {
    return await _db
        .from('ride_locations')
        .select('user_id, lat, lng')
        .eq('ride_id', rideId);
  }

  // ── Confirmar / recusar participação ──────────────────────
  static Future<void> confirmParticipation(String rideId) async {
    await _db
        .from('ride_participants')
        .update({'status': 'confirmed'})
        .eq('ride_id', rideId)
        .eq('user_id', _uid);
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
      creator: _rowToUser(creatorRow),
      // Mostra apenas: criador (sempre) + participantes que aceitaram o convite
      participants: participantRows
          .where((p) =>
              p['left_at'] == null &&
              (p['user_id'] == r['creator_id'] ||
                  p['status'] == 'confirmed'))
          .map((p) => _rowToUser(p['user'] as Map<String, dynamic>? ?? {}))
          .toList(),
      status: _parseStatus(r['status'] as String?),
      scheduledAt: r['scheduled_at'] != null
          ? DateTime.parse(r['scheduled_at'] as String)
          : null,
      isImmediate: r['is_immediate'] as bool? ?? false,
      createdAt: DateTime.parse(r['created_at'] as String),
      startedAt: r['started_at'] != null
          ? DateTime.parse(r['started_at'] as String)
          : null,
    );
  }

  static UserModel _rowToUser(Map<String, dynamic> r) => UserModel(
        id: r['id'] as String? ?? '',
        name: r['name'] as String? ?? '',
        username: r['username'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String?,
        motoModel: r['moto_model'] as String?,
        isOnline: r['is_online'] as bool? ?? false,
      );

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
