import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_model.dart';
import '../models/location_model.dart';
import '../models/user_model.dart';
import '../models/trip_photo_model.dart';
import '../models/stop_model.dart';
import '../models/session_invite.dart';
import '../models/event_model.dart';
import '../utils/image_utils.dart';
import 'supabase_social_service.dart';
import '../utils/db_time.dart';
import '../utils/participant_rows.dart';

class SupabaseTripService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Buscar MINHAS viagens ──────────────────────────────────
  // Só viagens que eu criei OU em que aceitei o convite (status confirmed).
  // Convite ainda não aceito fica só na aba de Convites; recusado/saído some.
  static Future<List<TripModel>> getTrips() async {
    // club_id IS NULL: viagens de motoclube ficam só no mural do clube, não na
    // lista pessoal de viagens.
    final created = await _db
        .from('trips')
        .select('id')
        .eq('creator_id', _uid)
        .isFilter('club_id', null)
        .timeout(const Duration(seconds: 15));
    final confirmed = await _db
        .from('trip_participants')
        .select('trip_id')
        .eq('user_id', _uid)
        .eq('status', 'confirmed')
        .timeout(const Duration(seconds: 15));

    final myTripIds = <String>{
      ...(created as List).map((r) => r['id'] as String),
      ...(confirmed as List).map((r) => r['trip_id'] as String),
    };
    if (myTripIds.isEmpty) return [];

    final rows = await _db
        .from('trips')
        .select()
        .inFilter('id', myTripIds.toList())
        .isFilter('club_id', null)
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

    final stopsByTrip = await _fetchStopsMap(tripIds);

    return rows.map((row) {
      final id = row['id'] as String;
      return _rowToTrip(row, profilesMap,
          participantIds: participantsByTrip[id] ?? [],
          stops: stopsByTrip[id] ?? const []);
    }).toList();
  }

  /// Paradas de várias viagens numa query só — a lista precisa delas para
  /// mostrar a contagem ("N PARADAS"). Sem isto os cards vinham sempre com 0,
  /// porque só [getTripById] carregava paradas.
  ///
  /// Best-effort: falhar aqui não pode derrubar a listagem inteira.
  static Future<Map<String, List<StopModel>>> _fetchStopsMap(
      List<String> tripIds) async {
    if (tripIds.isEmpty) return {};
    try {
      final rows = await _db
          .from('trip_stops')
          .select()
          .inFilter('trip_id', tripIds)
          .order('position', ascending: true)
          .timeout(const Duration(seconds: 15));
      final byTrip = <String, List<StopModel>>{};
      for (final r in rows as List) {
        final map = r as Map<String, dynamic>;
        byTrip
            .putIfAbsent(map['trip_id'] as String, () => [])
            .add(_rowToStop(map));
      }
      return byTrip;
    } catch (_) {
      return {};
    }
  }

  // ── Viagens concluídas de alguém (perfil público) ──────────
  /// Viagens **concluídas** de [userId] — criadas por ele ou com participação
  /// confirmada.
  ///
  /// Quem decide o que aparece é a RLS, não esta função: a `trips_select`
  /// (migration 034) devolve só viagem pública, do meu motoclube, ou em que eu
  /// mesmo estou. Uma viagem privada de terceiro simplesmente não volta na
  /// consulta — não há filtro de visibilidade escrito aqui de propósito, para
  /// não existir em dois lugares.
  static Future<List<TripModel>> getCompletedTripsOf(String userId) async {
    final criadas = await _db
        .from('trips')
        .select('id')
        .eq('creator_id', userId)
        .timeout(const Duration(seconds: 15));
    final participou = await _db
        .from('trip_participants')
        .select('trip_id')
        .eq('user_id', userId)
        .eq('status', 'confirmed')
        .timeout(const Duration(seconds: 15));

    final ids = <String>{
      ...(criadas as List).map((r) => r['id'] as String),
      ...(participou as List).map((r) => r['trip_id'] as String),
    };
    if (ids.isEmpty) return [];

    final rows = await _db
        .from('trips')
        .select()
        .inFilter('id', ids.toList())
        .eq('status', 'completed')
        .order('scheduled_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    if ((rows as List).isEmpty) return [];

    // Só o criador: a lista de participantes não é mostrada no perfil, e
    // buscá-la seria uma consulta a mais por viagem sem ninguém ver.
    final profilesMap = await _fetchProfilesMap(
        rows.map((r) => r['creator_id'] as String).toSet());
    return rows.map((row) => _rowToTrip(row, profilesMap)).toList();
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

    // Paradas: best-effort — uma falha aqui não pode impedir abrir a viagem.
    List<StopModel> stops = const [];
    try {
      stops = await getStops(id);
    } catch (_) {}

    return _rowToTrip(row, profilesMap,
        participantIds: participantIds.toList(), stops: stops);
  }

  // ── Viagens de um motoclube ────────────────────────────────
  static Future<List<TripModel>> getTripsByClub(String clubId) async {
    final rows = await _db
        .from('trips')
        .select()
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    if ((rows as List).isEmpty) return [];
    final tripIds = rows.map((r) => r['id'] as String).toList();
    final partRows = await _db
        .from('trip_participants')
        .select('trip_id, user_id')
        .inFilter('trip_id', tripIds);
    final byTrip = <String, List<String>>{};
    for (final p in partRows as List) {
      byTrip
          .putIfAbsent(p['trip_id'] as String, () => [])
          .add(p['user_id'] as String);
    }
    final creatorIds = rows.map((r) => r['creator_id'] as String).toSet();
    final partIds = byTrip.values.expand((e) => e).toSet();
    final profilesMap = await _fetchProfilesMap({...creatorIds, ...partIds});
    final stopsByTrip = await _fetchStopsMap(tripIds);
    return rows.map((row) {
      final id = row['id'] as String;
      return _rowToTrip(row, profilesMap,
          participantIds: byTrip[id] ?? [],
          stops: stopsByTrip[id] ?? const []);
    }).toList();
  }

  // ── Presença (RSVP + check-in) ─────────────────────────────
  static Future<void> setMyRsvp(String tripId, String rsvp) async {
    await _db.from('trip_participants').upsert({
      'trip_id': tripId,
      'user_id': _uid,
      'rsvp': rsvp,
    }, onConflict: 'trip_id,user_id');
  }

  static Future<Map<String, String>> getMyRsvps(List<String> tripIds) async {
    if (tripIds.isEmpty) return {};
    final rows = await _db
        .from('trip_participants')
        .select('trip_id, rsvp')
        .eq('user_id', _uid)
        .inFilter('trip_id', tripIds);
    final map = <String, String>{};
    for (final r in rows as List) {
      final rsvp = r['rsvp'] as String?;
      if (rsvp != null) map[r['trip_id'] as String] = rsvp;
    }
    return map;
  }

  static Future<List<Map<String, dynamic>>> getAttendance(String tripId) async {
    final rows = await _db
        .from('trip_participants')
        .select('user_id, rsvp, checked_in, user:profiles(*, profile_details(*))')
        .eq('trip_id', tripId)
        .not('rsvp', 'is', null);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static Future<void> setCheckIn(
      String tripId, String userId, bool value) async {
    await _db
        .from('trip_participants')
        .update({'checked_in': value})
        .eq('trip_id', tripId)
        .eq('user_id', userId);
  }

  // ── Roteiro da viagem (trip_schedule_items) ────────────────
  static Future<List<EventScheduleItem>> getSchedule(String tripId) async {
    final rows = await _db
        .from('trip_schedule_items')
        .select()
        .eq('trip_id', tripId)
        .order('position', ascending: true);
    return (rows as List)
        .map((r) => EventScheduleItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Substitui o roteiro inteiro (delete + insert), preservando a ordem.
  static Future<void> replaceSchedule(
      String tripId, List<EventScheduleItem> items) async {
    await _db.from('trip_schedule_items').delete().eq('trip_id', tripId);
    if (items.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      rows.add({
        'trip_id': tripId,
        'position': i,
        'time_label': it.timeLabel,
        'title': it.title,
        'description': it.description,
      });
    }
    await _db.from('trip_schedule_items').insert(rows);
  }

  // ── Paradas da viagem (trip_stops) ─────────────────────────
  static Future<List<StopModel>> getStops(String tripId) async {
    final rows = await _db
        .from('trip_stops')
        .select()
        .eq('trip_id', tripId)
        .order('position', ascending: true);
    return (rows as List)
        .map((r) => _rowToStop(r as Map<String, dynamic>))
        .toList();
  }

  /// Substitui as paradas inteiras (delete + insert), preservando a ordem.
  /// Mesmo padrão de [replaceSchedule].
  static Future<void> replaceStops(
      String tripId, List<StopModel> stops) async {
    await _db.from('trip_stops').delete().eq('trip_id', tripId);
    if (stops.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      rows.add({
        'trip_id': tripId,
        'position': i,
        'name': s.name,
        'category': s.category,
        'description': s.description,
        'image_url': s.imageUrl,
        'lat': s.location.lat,
        'lng': s.location.lng,
        'address': s.location.address,
      });
    }
    await _db.from('trip_stops').insert(rows);
  }

  static StopModel _rowToStop(Map<String, dynamic> r) => StopModel(
        id: r['id'] as String? ?? '',
        name: r['name'] as String? ?? '',
        description: r['description'] as String?,
        imageUrl: r['image_url'] as String?,
        category: r['category'] as String? ?? 'other',
        location: LocationModel(
          lat: (r['lat'] as num?)?.toDouble() ?? 0,
          lng: (r['lng'] as num?)?.toDouble() ?? 0,
          address: r['address'] as String?,
          label: r['name'] as String?,
        ),
      );

  // ── Busca perfis por IDs em uma só query ───────────────────
  static Future<Map<String, UserModel>> _fetchProfilesMap(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final profiles = await _db
        .from('profiles')
        .select(UserModel.dbColumns)
        .inFilter('id', ids.toList())
        .timeout(const Duration(seconds: 15));
    return {
      for (final p in profiles as List) (p['id'] as String): UserModel.fromMap(p),
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
    String? clubId,
    String? coverImage,
    List<EventScheduleItem> schedule = const [],
    bool isPublic = true,
    List<StopModel> stops = const [],
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
      'club_id': clubId,
      'cover_image': coverImage,
      'scheduled_at': DbTime.toDb(scheduledAt),
      'is_public': isPublic,
    }).select().single();

    final tripId = tripRow['id'] as String;

    if (schedule.isNotEmpty) {
      await replaceSchedule(tripId, schedule);
    }

    // Duas inserções, de propósito. O criador entra por 'auth.uid() = user_id';
    // os convidados entram pela cláusula de criador da policy (migration 040).
    // Antes era um lote só dentro de um try/catch: a RLS rejeitava o lote
    // inteiro por causa das linhas de terceiro, o catch engolia, e o convite
    // simplesmente não existia — sem nenhum erro aparecer.
    await _db
        .from('trip_participants')
        .insert({'trip_id': tripId, 'user_id': _uid, 'status': 'confirmed'});

    final invited = ParticipantRows.invitedRows(
      fkColumn: 'trip_id',
      parentId: tripId,
      creatorId: _uid,
      participantIds: participantIds,
    );
    if (invited.isNotEmpty) {
      await _db.from('trip_participants').insert(invited);
    }

    // Update trips_count for creator (best-effort — RPC may not exist)
    try {
      await _db.rpc('update_trips_count', params: {'p_user_id': _uid});
    } catch (_) {}

    // O aviso aos convidados sai do banco: a linha `waiting` inserida acima
    // dispara o trigger da migration 044.

    // Paradas (best-effort: a viagem já existe, não vale derrubar por isso).
    try {
      await replaceStops(tripId, stops);
    } catch (_) {}

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
    bool isPublic = true,
    List<StopModel> stops = const [],
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
      'scheduled_at': DbTime.toDb(scheduledAt),
      'is_public': isPublic,
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

    // Convidados novos são avisados pelo banco (trigger da migration 044),
    // disparado pela inserção acima.

    // Paradas: substitui pelo conjunto atual do formulário.
    try {
      await replaceStops(tripId, stops);
    } catch (_) {}

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

  // ── Convidar para uma viagem já criada ─────────────────────
  /// Grava os convites de [userIds] em [tripId]. O aviso a cada um sai do
  /// banco (trigger da migration 044) — não há mais notificação feita pelo app.
  ///
  /// Só o criador consegue (policy `trip_part_insert`, migration 040).
  /// Quem já estava na viagem é ignorado pelo `ON CONFLICT`.
  static Future<void> inviteParticipants(
      String tripId, List<String> userIds) async {
    final rows = ParticipantRows.invitedRows(
      fkColumn: 'trip_id',
      parentId: tripId,
      creatorId: _uid,
      participantIds: userIds,
    );
    if (rows.isEmpty) return;
    await _db.from('trip_participants').upsert(rows,
        onConflict: 'trip_id,user_id', ignoreDuplicates: true);
  }

  // ── Convites pendentes (participação 'waiting', não-criador) ───
  static Future<List<SessionInvite>> getPendingInvites() async {
    final rows = await _db
        .from('trip_participants')
        .select('trip:trips!inner(id, title, creator_id, scheduled_at)')
        .eq('user_id', _uid)
        .eq('status', 'waiting');

    final out = <SessionInvite>[];
    for (final r in rows as List) {
      final trip = r['trip'] as Map<String, dynamic>?;
      if (trip == null || trip['creator_id'] == _uid) continue; // ignora as minhas
      out.add(SessionInvite(
        sessionId: trip['id'] as String,
        title: trip['title'] as String? ?? 'Viagem',
        isRide: false,
        scheduledAt: DbTime.tryParse(trip['scheduled_at']),
      ));
    }
    return out;
  }

  // ── Confirmar / recusar participação ──────────────────────
  /// Upsert, não update: um `update` que não encontra linha devolve 204 sem
  /// erro nenhum — era exatamente assim que aceitar o convite não fazia nada e
  /// a tela ainda dizia "Você aceitou o convite!". Com upsert, quem foi
  /// convidado antes da migration 040 (e por isso nunca teve linha) entra ao
  /// tocar em aceitar de novo, sem precisar de conserto no banco.
  static Future<void> confirmParticipation(String tripId) async {
    await _db.from('trip_participants').upsert({
      'trip_id': tripId,
      'user_id': _uid,
      'status': 'confirmed',
    }, onConflict: 'trip_id,user_id');
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
    // Comprime para JPEG ≤ 360KB antes de subir.
    final jpeg = await ImageUtils.compressToJpeg(bytes);
    final path =
        'trip/$tripId/${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from('trip-photos').uploadBinary(
          path,
          jpeg,
          fileOptions:
              const FileOptions(contentType: 'image/jpeg', upsert: false),
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
    final expires = DbTime.parse(row['expires_at']);
      if (expires.isBefore(DateTime.now())) return null;
    return FeaturedPhotoModel(
      user: UserModel(id: _uid, name: '', username: ''),
      photoUrl: row['photo_url'] as String,
      tripId: row['trip_id'] as String?,
      featuredAt: DbTime.parse(row['featured_at']),
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
        featuredAt: DbTime.parse(r['featured_at']),
          expiresAt: DbTime.parse(r['expires_at']),
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
      {List<String> participantIds = const [],
      List<StopModel> stops = const []}) {
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
      stops: stops,
      participants: participantIds
          .map((uid) => profilesMap[uid])
          .whereType<UserModel>()
          .toList(),
      status: _parseStatus(r['status'] as String?),
      routeType: _parseRouteType(r['route_type'] as String?),
      scheduledAt: DbTime.tryParse(r['scheduled_at']),
      estimatedDistance: (r['estimated_distance'] as num?)?.toDouble(),
      estimatedDuration: r['estimated_duration'] as String?,
      coverImage: r['cover_image'] as String?,
      isPublic: r['is_public'] as bool? ?? true,
      clubId: r['club_id'] as String?,
      createdAt: DbTime.parse(r['created_at']),
    );
  }

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
