import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';

class SupabaseTripService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar todas as viagens ────────────────────────────────
  static Future<List<TripModel>> getTrips() async {
    final rows = await _db
        .from('trips')
        .select('''
          *,
          creator:profiles!trips_creator_id_fkey(*),
          participants:trip_participants(user:profiles(*))
        ''')
        .order('created_at', ascending: false);

    return rows.map(_rowToTrip).toList();
  }

  // ── Buscar viagem por ID ───────────────────────────────────
  static Future<TripModel?> getTripById(String id) async {
    final row = await _db
        .from('trips')
        .select('''
          *,
          creator:profiles!trips_creator_id_fkey(*),
          participants:trip_participants(user:profiles(*))
        ''')
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return _rowToTrip(row);
  }

  // ── Criar viagem ───────────────────────────────────────────
  static Future<TripModel> createTrip({
    required String title,
    String? description,
    required LocationModel origin,
    required LocationModel destination,
    List<String> participantIds = const [],
    RouteType routeType = RouteType.none,
    DateTime? scheduledAt,
  }) async {
    // Insert trip
    final tripRow = await _db.from('trips').insert({
      'creator_id': _uid,
      'title': title,
      'description': description,
      'origin_lat': origin.lat,
      'origin_lng': origin.lng,
      'origin_address': origin.address,
      'origin_label': origin.label,
      'destination_lat': destination.lat,
      'destination_lng': destination.lng,
      'destination_address': destination.address,
      'destination_label': destination.label,
      'route_type': routeType.name,
      'scheduled_at': scheduledAt?.toIso8601String(),
    }).select().single();

    final tripId = tripRow['id'] as String;

    // Add creator as participant
    final allParticipants = [_uid, ...participantIds.where((id) => id != _uid)];
    await _db.from('trip_participants').insert(
      allParticipants.map((id) => {'trip_id': tripId, 'user_id': id}).toList(),
    );

    // Update trips_count for creator
    await _db.rpc('update_trips_count', params: {'p_user_id': _uid});

    return (await getTripById(tripId))!;
  }

  // ── Atualizar status ───────────────────────────────────────
  static Future<void> updateStatus(String tripId, TripStatus status) async {
    await _db
        .from('trips')
        .update({'status': status.name})
        .eq('id', tripId)
        .eq('creator_id', _uid);
  }

  // ── Deletar viagem ─────────────────────────────────────────
  static Future<void> deleteTrip(String tripId) async {
    await _db
        .from('trips')
        .delete()
        .eq('id', tripId)
        .eq('creator_id', _uid);
  }

  // ── Entrar / sair da viagem ────────────────────────────────
  static Future<void> joinTrip(String tripId) async {
    await _db.from('trip_participants').upsert({
      'trip_id': tripId,
      'user_id': _uid,
    });
  }

  static Future<void> leaveTrip(String tripId) async {
    await _db
        .from('trip_participants')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', _uid);
  }

  // ── Helpers ────────────────────────────────────────────────
  static TripModel _rowToTrip(Map<String, dynamic> r) {
    final creatorRow = r['creator'] as Map<String, dynamic>? ?? {};
    final participantRows =
        (r['participants'] as List? ?? []).cast<Map<String, dynamic>>();

    return TripModel(
      id: r['id'] as String,
      title: r['title'] as String,
      description: r['description'] as String?,
      origin: LocationModel(
        lat: (r['origin_lat'] as num).toDouble(),
        lng: (r['origin_lng'] as num).toDouble(),
        address: r['origin_address'] as String?,
        label: r['origin_label'] as String?,
      ),
      destination: LocationModel(
        lat: (r['destination_lat'] as num).toDouble(),
        lng: (r['destination_lng'] as num).toDouble(),
        address: r['destination_address'] as String?,
        label: r['destination_label'] as String?,
      ),
      creator: _rowToUser(creatorRow),
      participants: participantRows
          .map((p) => _rowToUser(p['user'] as Map<String, dynamic>? ?? {}))
          .toList(),
      status: _parseStatus(r['status'] as String?),
      routeType: _parseRouteType(r['route_type'] as String?),
      scheduledAt: r['scheduled_at'] != null
          ? DateTime.parse(r['scheduled_at'] as String)
          : null,
      estimatedDistance: (r['estimated_distance'] as num?)?.toDouble(),
      estimatedDuration: r['estimated_duration'] as String?,
      coverImage: r['cover_image'] as String?,
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

  static TripStatus _parseStatus(String? s) {
    switch (s) {
      case 'active': return TripStatus.active;
      case 'completed': return TripStatus.completed;
      case 'cancelled': return TripStatus.cancelled;
      default: return TripStatus.planned;
    }
  }

  static RouteType _parseRouteType(String? s) {
    switch (s) {
      case 'scenic': return RouteType.scenic;
      case 'gastronomic': return RouteType.gastronomic;
      case 'shortest': return RouteType.shortest;
      case 'safest': return RouteType.safest;
      default: return RouteType.none;
    }
  }
}
