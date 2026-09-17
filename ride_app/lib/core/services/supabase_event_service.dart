import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import '../models/user_model.dart';
import '../utils/storage_utils.dart';
import '../utils/db_time.dart';

class SupabaseEventService {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // Seleção padrão: evento + criador + programação + patrocinadores +
  // participantes (com perfil).
  static const _select = '''
        *,
        creator:profiles!events_creator_id_fkey(*),
        schedule:event_schedule_items(*),
        sponsors:event_sponsors(*),
        participants:event_participants(user:profiles(*))
      ''';

  // ── Criar evento ───────────────────────────────────────────
  static Future<EventModel> createEvent({
    required String title,
    String? description,
    String? bannerUrl,
    double? lat,
    double? lng,
    String? address,
    String? locationLabel,
    String? stateUf,
    String? city,
    required DateTime startsAt,
    DateTime? endsAt,
    String? clubId,
    /// Marcado na tela de criação. Antes vinha do motoclube por trigger — o
    /// trigger foi removido na 034, então o valor enviado aqui é o que vale.
    bool isPublic = true,
    List<EventScheduleItem> schedule = const [],
    List<EventSponsor> sponsors = const [],
    List<String> participantIds = const [],
  }) async {
    final row = await _db.from('events').insert({
      'creator_id': _uid,
      'title': title,
      'description': description,
      'banner_url': bannerUrl,
      'lat': lat,
      'lng': lng,
      'address': address,
      'location_label': locationLabel,
      'state_uf': stateUf,
      'city': city,
      'club_id': clubId,
      'is_public': isPublic,
      'starts_at': DbTime.toDb(startsAt),
      'ends_at': DbTime.toDb(endsAt),
    }).select('id').single();

    final eventId = row['id'] as String;
    await _replaceSchedule(eventId, schedule);
    await _replaceSponsors(eventId, sponsors);
    await _replaceParticipants(eventId, participantIds);

    return (await getEventById(eventId))!;
  }

  // ── Atualizar evento ───────────────────────────────────────
  static Future<EventModel?> updateEvent(
    String eventId, {
    String? title,
    String? description,
    String? bannerUrl,
    double? lat,
    double? lng,
    String? address,
    String? locationLabel,
    String? stateUf,
    String? city,
    DateTime? startsAt,
    DateTime? endsAt,
    List<EventScheduleItem>? schedule,
    List<EventSponsor>? sponsors,
    List<String>? participantIds,
    // Quando true, notifica quem marcou interesse de que o evento mudou.
    bool notifyInterested = false,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (description != null) updates['description'] = description;
    if (bannerUrl != null) updates['banner_url'] = bannerUrl;
    if (lat != null) updates['lat'] = lat;
    if (lng != null) updates['lng'] = lng;
    if (address != null) updates['address'] = address;
    if (locationLabel != null) updates['location_label'] = locationLabel;
    if (stateUf != null) updates['state_uf'] = stateUf;
    if (city != null) updates['city'] = city;
    if (startsAt != null) updates['starts_at'] = DbTime.toDb(startsAt);
    if (endsAt != null) updates['ends_at'] = DbTime.toDb(endsAt);

    if (updates.isNotEmpty) {
      await _db.from('events').update(updates).eq('id', eventId);
    }
    if (schedule != null) await _replaceSchedule(eventId, schedule);
    if (sponsors != null) await _replaceSponsors(eventId, sponsors);
    if (participantIds != null) {
      await _replaceParticipants(eventId, participantIds);
    }

    if (notifyInterested) {
      await _notifyInterestedOfUpdate(eventId, title);
    }
    return getEventById(eventId);
  }

  /// Notifica (best-effort) todos que marcaram interesse de que o evento foi
  /// alterado. Não notifica o próprio criador.
  static Future<void> _notifyInterestedOfUpdate(
      String eventId, String? title) async {
    try {
      final rows = await _db
          .from('event_interests')
          .select('user_id')
          .eq('event_id', eventId);
      final userIds = (rows as List)
          .map((r) => r['user_id'] as String)
          .where((id) => id != _uid)
          .toList();
      if (userIds.isEmpty) return;

      // Busca o título atual caso não tenha sido passado.
      var eventTitle = title;
      if (eventTitle == null) {
        final e = await _db
            .from('events')
            .select('title')
            .eq('id', eventId)
            .maybeSingle();
        eventTitle = e?['title'] as String? ?? 'um evento';
      }

      await _db.from('notifications').insert(
            userIds
                .map((uid) => {
                      'user_id': uid,
                      'type': 'event_update',
                      'title': 'Evento atualizado',
                      'body':
                          'O evento "$eventTitle" que você tem interesse foi atualizado.',
                      'data': {'eventId': eventId},
                    })
                .toList(),
          );
    } catch (_) {
      // best-effort: não derruba a edição se a notificação falhar
    }
  }

  // Substitui a programação inteira (delete + insert) — simples e idempotente.
  static Future<void> _replaceSchedule(
      String eventId, List<EventScheduleItem> schedule) async {
    await _db.from('event_schedule_items').delete().eq('event_id', eventId);
    if (schedule.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < schedule.length; i++) {
      final item = schedule[i];
      rows.add(EventScheduleItem(
        position: i,
        timeLabel: item.timeLabel,
        title: item.title,
        description: item.description,
      ).toInsertMap(eventId));
    }
    await _db.from('event_schedule_items').insert(rows);
  }

  // Substitui os patrocinadores (delete + insert), preservando a ordem.
  static Future<void> _replaceSponsors(
      String eventId, List<EventSponsor> sponsors) async {
    await _db.from('event_sponsors').delete().eq('event_id', eventId);
    if (sponsors.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < sponsors.length; i++) {
      final s = sponsors[i];
      rows.add(EventSponsor(
        position: i,
        name: s.name,
        logoUrl: s.logoUrl,
      ).toInsertMap(eventId));
    }
    await _db.from('event_sponsors').insert(rows);
  }

  // Substitui os participantes extras (delete + insert).
  static Future<void> _replaceParticipants(
      String eventId, List<String> userIds) async {
    await _db.from('event_participants').delete().eq('event_id', eventId);
    final unique = userIds.toSet().toList();
    if (unique.isEmpty) return;
    await _db.from('event_participants').insert(
          unique
              .map((id) => {'event_id': eventId, 'user_id': id})
              .toList(),
        );
  }

  // ── Eventos por UF (home) ──────────────────────────────────
  /// Eventos futuros da UF [uf], ordenados pela data de início. Marca
  /// isInterested usando o set de interesses do usuário.
  static Future<List<EventModel>> getEventsByState(String uf,
      {int limit = 20}) async {
    final rows = await _db
        .from('events')
        .select(_select)
        .eq('state_uf', uf)
        // is_public: eventos públicos (empresa/pessoal sempre; clube só se o
        // dono marcou "eventos públicos"). Privados de clube ficam no mural.
        .eq('is_public', true)
        .gte('starts_at', DbTime.nowForDb())
        .order('starts_at', ascending: true)
        .limit(limit);
    return _attachInterest((rows as List).cast<Map<String, dynamic>>());
  }

  // ── Busca de eventos (pela busca global) ───────────────────
  static Future<List<EventModel>> searchEvents(String query,
      {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final rows = await _db
        .from('events')
        .select(_select)
        .or('title.ilike.%$q%,description.ilike.%$q%,city.ilike.%$q%,location_label.ilike.%$q%')
        .gte('starts_at', DbTime.nowForDb())
        .order('starts_at', ascending: true)
        .limit(limit);
    return _attachInterest((rows as List).cast<Map<String, dynamic>>());
  }

  // ── Eventos de um motoclube ────────────────────────────────
  static Future<List<EventModel>> getEventsByClub(String clubId) async {
    final rows = await _db
        .from('events')
        .select(_select)
        .eq('club_id', clubId)
        .order('starts_at', ascending: true);
    return _attachInterest((rows as List).cast<Map<String, dynamic>>());
  }

  // ── Presença (RSVP + check-in) ─────────────────────────────
  /// Define a presença do usuário logado ('going'|'maybe'|'declined').
  static Future<void> setMyRsvp(String eventId, String rsvp) async {
    await _db.from('event_participants').upsert({
      'event_id': eventId,
      'user_id': _uid,
      'rsvp': rsvp,
    }, onConflict: 'event_id,user_id');
  }

  /// RSVP do usuário logado para uma lista de eventos (eventId → rsvp).
  static Future<Map<String, String>> getMyRsvps(List<String> eventIds) async {
    if (eventIds.isEmpty) return {};
    final rows = await _db
        .from('event_participants')
        .select('event_id, rsvp')
        .eq('user_id', _uid)
        .inFilter('event_id', eventIds);
    final map = <String, String>{};
    for (final r in rows as List) {
      final rsvp = r['rsvp'] as String?;
      if (rsvp != null) map[r['event_id'] as String] = rsvp;
    }
    return map;
  }

  /// Lista de presença de um evento (quem marcou rsvp), com perfil.
  static Future<List<Map<String, dynamic>>> getAttendance(String eventId) async {
    final rows = await _db
        .from('event_participants')
        .select('user_id, rsvp, checked_in, user:profiles(*)')
        .eq('event_id', eventId)
        .not('rsvp', 'is', null);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  static Future<void> setCheckIn(
      String eventId, String userId, bool value) async {
    await _db
        .from('event_participants')
        .update({'checked_in': value})
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  // ── Eventos criados por uma empresa ────────────────────────
  static Future<List<EventModel>> getEventsByCreator(String creatorId,
      {bool upcomingOnly = false}) async {
    // club_id IS NULL: eventos de motoclube não entram no perfil (empresa/pessoal);
    // eles vivem só no mural do clube.
    var query = _db
        .from('events')
        .select(_select)
        .eq('creator_id', creatorId)
        .isFilter('club_id', null);
    if (upcomingOnly) {
      query = query.gte('starts_at', DbTime.nowForDb());
    }
    final rows = await query.order('starts_at', ascending: true);
    return _attachInterest((rows as List).cast<Map<String, dynamic>>());
  }

  // ── Detalhe ────────────────────────────────────────────────
  static Future<EventModel?> getEventById(String id) async {
    final row =
        await _db.from('events').select(_select).eq('id', id).maybeSingle();
    if (row == null) return null;
    final interested = await isInterested(id);
    return EventModel.fromMap(row, isInterested: interested);
  }

  // ── Interesse ──────────────────────────────────────────────
  static Future<bool> isInterested(String eventId) async {
    final row = await _db
        .from('event_interests')
        .select('event_id')
        .eq('event_id', eventId)
        .eq('user_id', _uid)
        .maybeSingle();
    return row != null;
  }

  /// Alterna o interesse e retorna o novo estado (true = passou a ter interesse).
  static Future<bool> toggleInterest(String eventId) async {
    final already = await isInterested(eventId);
    if (already) {
      await _db
          .from('event_interests')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', _uid);
      return false;
    } else {
      await _db.from('event_interests').insert({
        'event_id': eventId,
        'user_id': _uid,
      });
      return true;
    }
  }

  /// Lista os usuários que marcaram interesse no evento (com perfil).
  static Future<List<UserModel>> getInterestedUsers(String eventId) async {
    final rows = await _db
        .from('event_interests')
        .select('user:profiles(*)')
        .eq('event_id', eventId);
    return (rows as List)
        .map((r) => r['user'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((m) => UserModel.fromMap(m))
        .toList();
  }

  // ── Deletar ────────────────────────────────────────────────
  static Future<void> deleteEvent(String eventId) async {
    await _db.from('events').delete().eq('id', eventId).eq('creator_id', _uid);
  }

  // ── Upload de banner (reusa bucket 'avatars') ──────────────
  static Future<String> uploadBanner(Uint8List bytes) async {
    return StorageUtils.uploadImageUnique(
      bucket: 'avatars',
      uid: _uid,
      prefix: 'event',
      bytes: bytes,
    );
  }

  // ── Upload de logo de patrocinador (reusa bucket 'avatars') ─
  static Future<String> uploadSponsorLogo(Uint8List bytes) async {
    return StorageUtils.uploadImageUnique(
      bucket: 'avatars',
      uid: _uid,
      prefix: 'sponsor',
      bytes: bytes,
    );
  }

  /// Usuários cadastrados pra buscar como participantes extras.
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

  // ── Helpers ────────────────────────────────────────────────
  /// Resolve isInterested em lote: busca o conjunto de event_ids em que o
  /// usuário marcou interesse e seta a flag em cada modelo (1 query só).
  static Future<List<EventModel>> _attachInterest(
      List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final interestRows = await _db
        .from('event_interests')
        .select('event_id')
        .eq('user_id', _uid)
        .inFilter('event_id', ids);
    final interestedIds = (interestRows as List)
        .map((r) => r['event_id'] as String)
        .toSet();
    return rows
        .map((r) => EventModel.fromMap(r,
            isInterested: interestedIds.contains(r['id'] as String)))
        .toList();
  }
}
