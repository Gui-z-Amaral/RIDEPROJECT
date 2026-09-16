import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/share_preview.dart';
import '../utils/db_time.dart';

/// Carrega a versão **pública** de um evento, viagem ou rolê — o que um
/// visitante sem login vê ao abrir um link compartilhado.
///
/// Não reaproveita os services de detalhe de propósito: aqueles fazem várias
/// queries, montam participantes e alguns usam `auth.currentUser!.id`, que
/// estoura sem sessão. Aqui é **uma query por tipo, só com as colunas
/// públicas** — o que não é selecionado não tem como vazar.
///
/// As linhas já eram legíveis sem login (`events_select`/`rides_select` são
/// `USING (true)` e `trips_select` libera viagem sem clube), então isto não
/// abre nada novo no banco; o que muda é o recorte que a tela mostra.
class SupabaseShareService {
  SupabaseShareService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<SharePreview?> preview(ShareKind kind, String id) async {
    try {
      return switch (kind) {
        ShareKind.event => await _event(id),
        ShareKind.trip => await _trip(id),
        ShareKind.ride => await _ride(id),
      };
    } catch (_) {
      // Link quebrado ou registro apagado: a tela mostra "não encontrado".
      return null;
    }
  }

  /// Evento mostra tudo: existe para atrair gente.
  static Future<SharePreview?> _event(String id) async {
    final row = await _db
        .from('events')
        .select('id, title, description, banner_url, starts_at, '
            'city, state_uf, location_label, address, creator_id')
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    if (row == null) return null;

    final city = row['city'] as String?;
    final uf = row['state_uf'] as String?;
    final place = [
      row['location_label'] as String?,
      [city, uf].where(_filled).join(' - '),
    ].where(_filled).join(' · ');

    final creator = await _profile(row['creator_id'] as String?);
    return SharePreview(
      kind: ShareKind.event,
      id: id,
      title: row['title'] as String? ?? 'Evento',
      imageUrl: row['banner_url'] as String?,
      startsAt: DbTime.tryParse(row['starts_at']),
      placeLabel: place.isEmpty ? null : place,
      description: row['description'] as String?,
      organizerName: creator?.$1,
      organizerAvatar: creator?.$2,
    );
  }

  /// Viagem: capa, título, data, **cidade do destino** e quem organiza.
  /// Sem origem, sem paradas, sem rota, sem descrição.
  static Future<SharePreview?> _trip(String id) async {
    final row = await _db
        .from('trips')
        .select('id, title, cover_image, scheduled_at, '
            'destination_address, creator_id')
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    if (row == null) return null;

    final creator = await _profile(row['creator_id'] as String?);
    return SharePreview(
      kind: ShareKind.trip,
      id: id,
      title: row['title'] as String? ?? 'Viagem',
      imageUrl: row['cover_image'] as String?,
      startsAt: DbTime.tryParse(row['scheduled_at']),
      placeLabel:
          SharePreview.cityFromAddress(row['destination_address'] as String?),
      organizerName: creator?.$1,
      organizerAvatar: creator?.$2,
    );
  }

  /// Rolê: título, data, **cidade** e quem organiza. O ponto de encontro é a
  /// origem de gente de verdade — só a cidade sai daqui, nunca o endereço.
  static Future<SharePreview?> _ride(String id) async {
    final row = await _db
        .from('rides')
        .select('id, title, scheduled_at, meeting_address, creator_id')
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    if (row == null) return null;

    final creator = await _profile(row['creator_id'] as String?);
    return SharePreview(
      kind: ShareKind.ride,
      id: id,
      title: row['title'] as String? ?? 'Rolê',
      startsAt: DbTime.tryParse(row['scheduled_at']),
      placeLabel:
          SharePreview.cityFromAddress(row['meeting_address'] as String?),
      organizerName: creator?.$1,
      organizerAvatar: creator?.$2,
    );
  }

  /// Nome e avatar de quem organiza. Falha aqui não derruba o preview.
  static Future<(String?, String?)?> _profile(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final row = await _db
          .from('profiles')
          .select('name, avatar_url')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));
      if (row == null) return null;
      return (row['name'] as String?, row['avatar_url'] as String?);
    } catch (_) {
      return null;
    }
  }

  static bool _filled(String? s) => s != null && s.trim().isNotEmpty;
}
