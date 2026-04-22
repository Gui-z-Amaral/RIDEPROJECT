import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../models/trip_photo_model.dart';
import 'supabase_notification_service.dart';
import 'supabase_social_service.dart';

class SupabaseTripService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar todas as viagens ────────────────────────────────
  static Future<List<TripModel>> getTrips() async {
    // Sem PostgREST join — evita hang causado por RLS em joins
    final rows = await _db
        .from('trips')
        .select()
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));

    if (rows.isEmpty) return [];

    final tripIds = rows.map((r) => r['id'] as String).toList();

    final participantRows = await _db
        .from('trip_participants')
        .select('trip_id, user_id')
        .inFilter('trip_id', tripIds)
        .timeout(const Duration(seconds: 15));

    final participantsByTrip = <String, List<String>>{};
    for (final p in participantRows as List) {
      final tid = p['trip_id'] as String;
      final uid = p['user_id'] as String;
      participantsByTrip.putIfAbsent(tid, () => []).add(uid);
    }

    // Busca criadores + participantes numa única query de perfis
    final creatorIds = rows.map((r) => r['creator_id'] as String).toSet();
    final participantIds =
        participantsByTrip.values.expand((ids) => ids).toSet();
    final profilesMap = await _fetchProfilesMap({...creatorIds, ...participantIds});

    return rows.map((row) {
      final ids = participantsByTrip[row['id'] as String] ?? [];
      return _rowToTrip(row, profilesMap, participantIds: ids);
    }).toList();
  }

  // ── Buscar viagem por ID ───────────────────────────────────
  static Future<TripModel?> getTripById(String id) async {
    // Sem PostgREST join — evita hang causado por RLS em joins
    final row = await _db
        .from('trips')
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));

    if (row == null) return null;

    final participantRows = await _db
        .from('trip_participants')
        .select('user_id')
        .eq('trip_id', id)
        .timeout(const Duration(seconds: 15));

    final participantIds = (participantRows as List)
        .map((p) => p['user_id'] as String)
        .toSet();

    final creatorId = row['creator_id'] as String? ?? '';
    final allIds = {...participantIds, if (creatorId.isNotEmpty) creatorId};
    final profilesMap = await _fetchProfilesMap(allIds);

    return _rowToTrip(row, profilesMap, participantIds: participantIds.toList());
  }

  // ── Busca perfis por IDs em uma só query ───────────────────
  static Future<Map<String, UserModel>> _fetchProfilesMap(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final profiles = await _db
        .from('profiles')
        .select()
        .inFilter('id', ids.toList())
        .timeout(const Duration(seconds: 15));
    return {
      for (final p in profiles as List) (p['id'] as String): _rowToUser(p),
    };
  }

  // ── Criar viagem ───────────────────────────────────────────
  static Future<TripModel> createTrip({
    required String title,
    String? description,
    required LocationModel origin,
    required LocationModel destination,
    List<String> participantIds = const [],
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
      'scheduled_at': scheduledAt?.toIso8601String(),
    }).select().single();

    final tripId = tripRow['id'] as String;

    // Add creator as participant; try to batch-add others.
    // If RLS prevents inserting rows for other users, fall back to
    // inserting just the creator so the trip save always succeeds.
    final allParticipants = [_uid, ...participantIds.where((id) => id != _uid)];
    try {
      await _db.from('trip_participants').insert(
        allParticipants.map((id) => {'trip_id': tripId, 'user_id': id}).toList(),
      );
    } catch (_) {
      // Batch failed (likely RLS restriction) — ensure at least creator is added
      await _db.from('trip_participants').insert(
        {'trip_id': tripId, 'user_id': _uid},
      );
    }

    // Update trips_count for creator (best-effort — RPC may not exist)
    try {
      await _db.rpc('update_trips_count', params: {'p_user_id': _uid});
    } catch (_) {}

    // Send trip_invite notifications to non-creator participants
    final invitedIds = participantIds.where((id) => id != _uid).toList();
    if (invitedIds.isNotEmpty) {
      try {
        final creatorRow = await _db
            .from('profiles')
            .select('name')
            .eq('id', _uid)
            .single();
        final creatorName = creatorRow['name'] as String? ?? 'Alguém';
        await SupabaseNotificationService.sendInviteNotifications(
          userIds: invitedIds,
          type: 'trip_invite',
          title: '$creatorName te convidou para uma viagem',
          body: '$title · ${destination.address ?? destination.label ?? 'Destino'}',
          data: {
            'tripId': tripId,
            'tripTitle': title,
            'originAddress': origin.address ?? '',
            'destinationAddress': destination.address ?? '',
          },
        );
      } catch (_) {}
    }

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

  // ── Editar viagem (apenas criador, apenas planejadas) ──────
  static Future<TripModel> updateTrip({
    required String tripId,
    required String title,
    required LocationModel origin,
    required LocationModel destination,
    DateTime? scheduledAt,
    List<String> participantIds = const [],
  }) async {
    await _db.from('trips').update({
      'title': title,
      'origin_lat': origin.lat,
      'origin_lng': origin.lng,
      'origin_address': origin.address,
      'origin_label': origin.label,
      'destination_lat': destination.lat,
      'destination_lng': destination.lng,
      'destination_address': destination.address,
      'destination_label': destination.label,
      'scheduled_at': scheduledAt?.toIso8601String(),
    }).eq('id', tripId).eq('creator_id', _uid);

    // Sincroniza participantes (mantém criador, adiciona novos, remove retirados)
    final existingRows = await _db
        .from('trip_participants')
        .select('user_id')
        .eq('trip_id', tripId);
    final existingIds = (existingRows as List)
        .map((r) => r['user_id'] as String)
        .toSet();
    final desiredIds = {_uid, ...participantIds};

    final toRemove = existingIds
        .difference(desiredIds)
        .where((id) => id != _uid)
        .toList();
    final toAdd = desiredIds.difference(existingIds).toList();

    for (final uid in toRemove) {
      try {
        await _db
            .from('trip_participants')
            .delete()
            .eq('trip_id', tripId)
            .eq('user_id', uid);
      } catch (_) {}
    }
    if (toAdd.isNotEmpty) {
      try {
        await _db.from('trip_participants').insert(
          toAdd.map((id) => {'trip_id': tripId, 'user_id': id}).toList(),
        );
      } catch (_) {}
    }

    // Notifica convidados novos (apenas os adicionados nesta edição)
    final newlyInvited = toAdd.where((id) => id != _uid).toList();
    if (newlyInvited.isNotEmpty) {
      try {
        final creatorRow = await _db
            .from('profiles')
            .select('name')
            .eq('id', _uid)
            .single();
        final creatorName = creatorRow['name'] as String? ?? 'Alguém';
        await SupabaseNotificationService.sendInviteNotifications(
          userIds: newlyInvited,
          type: 'trip_invite',
          title: '$creatorName te convidou para uma viagem',
          body: '$title · ${destination.address ?? destination.label ?? 'Destino'}',
          data: {
            'tripId': tripId,
            'tripTitle': title,
            'originAddress': origin.address ?? '',
            'destinationAddress': destination.address ?? '',
          },
        );
      } catch (_) {}
    }

    return (await getTripById(tripId))!;
  }

  // ── Deletar viagem ─────────────────────────────────────────
  static Future<void> deleteTrip(String tripId) async {
    // Remove participants first (no CASCADE on FK)
    await _db.from('trip_participants').delete().eq('trip_id', tripId);
    await _db
        .from('trips')
        .delete()
        .eq('id', tripId)
        .eq('creator_id', _uid);
  }

  // ── Confirmar / recusar participação ──────────────────────
  static Future<void> confirmParticipation(String tripId) async {
    await _db
        .from('trip_participants')
        .update({'status': 'confirmed'})
        .eq('trip_id', tripId)
        .eq('user_id', _uid);
  }

  static Future<void> declineParticipation(String tripId) async {
    await _db
        .from('trip_participants')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', _uid);
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

  // ── Fotos da viagem ────────────────────────────────────────
  static Future<TripPhotoModel> uploadTripPhoto(
      String tripId, Uint8List bytes, String extension) async {
    final path =
        'trip/$tripId/${_uid}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _db.storage.from('trip-photos').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(contentType: 'image/$extension', upsert: false),
        );
    final url = _db.storage.from('trip-photos').getPublicUrl(path);

    final row = await _db.from('trip_photos').insert({
      'trip_id': tripId,
      'uploaded_by': _uid,
      'photo_url': url,
    }).select().single();

    return TripPhotoModel.fromRow(row);
  }

  static Future<List<TripPhotoModel>> getTripPhotos(String tripId) async {
    final rows = await _db
        .from('trip_photos')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => TripPhotoModel.fromRow(r)).toList();
  }

  static Future<void> deleteTripPhoto(String photoId) async {
    await _db
        .from('trip_photos')
        .delete()
        .eq('id', photoId)
        .eq('uploaded_by', _uid);
  }

  // ── Destaques (featured photo) ─────────────────────────────
  /// Define a foto destacada do usuário atual. Substitui qualquer destaque
  /// anterior (PRIMARY KEY user_id). Expira em 7 dias.
  static Future<void> setFeaturedPhoto({
    required String tripId,
    required String photoUrl,
  }) async {
    final now = DateTime.now().toUtc();
    final expires = now.add(const Duration(days: 7));
    await _db.from('featured_photos').upsert({
      'user_id': _uid,
      'trip_id': tripId,
      'photo_url': photoUrl,
      'featured_at': now.toIso8601String(),
      'expires_at': expires.toIso8601String(),
    });
  }

  static Future<void> clearFeaturedPhoto() async {
    await _db.from('featured_photos').delete().eq('user_id', _uid);
  }

  /// Foto destacada atual do usuário (se existe e não expirou).
  static Future<FeaturedPhotoModel?> getMyFeaturedPhoto() async {
    final row = await _db
        .from('featured_photos')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    if (row == null) return null;
    final expires = DateTime.parse(row['expires_at'] as String);
    if (expires.isBefore(DateTime.now().toUtc())) return null;
    return FeaturedPhotoModel(
      user: UserModel(id: _uid, name: '', username: ''),
      photoUrl: row['photo_url'] as String,
      tripId: row['trip_id'] as String?,
      featuredAt: DateTime.parse(row['featured_at'] as String),
      expiresAt: expires,
    );
  }

  /// Destaques ativos dos amigos (não expirados).
  static Future<List<FeaturedPhotoModel>> getFriendsFeaturedPhotos() async {
    final friends = await SupabaseSocialService.getFriends();
    if (friends.isEmpty) return [];

    final friendsMap = {for (final f in friends) f.id: f};
    final ids = friends.map((f) => f.id).toList();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final rows = await _db
        .from('featured_photos')
        .select()
        .inFilter('user_id', ids)
        .gt('expires_at', nowIso)
        .order('featured_at', ascending: false);

    return (rows as List).map((r) {
      final user = friendsMap[r['user_id'] as String];
      if (user == null) return null;
      return FeaturedPhotoModel(
        user: user,
        photoUrl: r['photo_url'] as String,
        tripId: r['trip_id'] as String?,
        featuredAt: DateTime.parse(r['featured_at'] as String),
        expiresAt: DateTime.parse(r['expires_at'] as String),
      );
    }).whereType<FeaturedPhotoModel>().toList();
  }

  /// Marca a viagem como concluída (apenas criador).
  static Future<void> finalizeTrip(String tripId) async {
    await updateStatus(tripId, TripStatus.completed);
  }

  // ── Helpers ────────────────────────────────────────────────
  static TripModel _rowToTrip(
      Map<String, dynamic> r, Map<String, UserModel> profilesMap,
      {List<String> participantIds = const []}) {
    final creatorId = r['creator_id'] as String? ?? '';
    final creator = profilesMap[creatorId] ??
        UserModel(id: creatorId, name: '', username: '');

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
      creator: creator,
      participants: participantIds
          .map((uid) => profilesMap[uid])
          .whereType<UserModel>()
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
