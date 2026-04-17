import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';

class SupabaseRideService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar todos os rolês ──────────────────────────────────
  static Future<List<RideModel>> getRides() async {
    final rows = await _db
        .from('rides')
        .select('''
          *,
          creator:profiles!rides_creator_id_fkey(*),
          participants:ride_participants(user:profiles(*))
        ''')
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
          participants:ride_participants(user:profiles(*))
        ''')
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return _rowToRide(row);
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
    await _db
        .from('rides')
        .update({'status': status.name})
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

  static Future<void> leaveRide(String rideId) async {
    await _db
        .from('ride_participants')
        .delete()
        .eq('ride_id', rideId)
        .eq('user_id', _uid);
  }

  // ── Deletar rolê ───────────────────────────────────────────
  static Future<void> deleteRide(String rideId) async {
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
      participants: participantRows
          .map((p) => _rowToUser(p['user'] as Map<String, dynamic>? ?? {}))
          .toList(),
      status: _parseStatus(r['status'] as String?),
      scheduledAt: r['scheduled_at'] != null
          ? DateTime.parse(r['scheduled_at'] as String)
          : null,
      isImmediate: r['is_immediate'] as bool? ?? false,
      createdAt: DateTime.parse(r['created_at'] as String),
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
