import 'package:share_plus/share_plus.dart';
import '../constants/app_links.dart';
import '../models/event_model.dart';
import '../models/ride_model.dart';
import '../models/share_preview.dart';
import '../models/trip_model.dart';

/// Compartilhamento reutilizável (abre a folha de compartilhar do sistema —
/// WhatsApp, etc.), com um link que aponta para o app/site.
///
/// Feito genérico de propósito: novos tipos (viagem, rolê, clube, perfil) são
/// só mais um método aqui, reaproveitando [shareLink].
class ShareUtils {
  ShareUtils._();

  /// Compartilha qualquer coisa: título + link (+ linha extra opcional).
  static Future<void> shareLink({
    required String title,
    required String url,
    String? extra,
  }) async {
    final text = [
      title,
      if (extra != null && extra.isNotEmpty) extra,
      url,
    ].join('\n');
    await Share.share(text, subject: title);
  }

  /// Compartilha um evento (para qualquer pessoa, não só amigos).
  static Future<void> shareEvent(EventModel e) => shareLink(
        title: 'Evento no RideApp: ${e.title}',
        url: AppLinks.event(e.id),
        extra: subtitle(city: e.city, when: e.startsAt),
      );

  /// Compartilha uma viagem. O link mostra só o essencial para quem não tem
  /// conta — origem, paradas e rota ficam de fora (ver [SharePreview]).
  static Future<void> shareTrip(TripModel t) => shareLink(
        title: 'Viagem no RideApp: ${t.title}',
        url: AppLinks.trip(t.id),
        extra: subtitle(
          city: SharePreview.cityFromAddress(t.destination.address),
          when: t.scheduledAt,
        ),
      );

  /// Compartilha um rolê agendado.
  static Future<void> shareRide(RideModel r) => shareLink(
        title: 'Rolê no RideApp: ${r.title}',
        url: AppLinks.ride(r.id),
        extra: subtitle(
          city: SharePreview.cityFromAddress(r.meetingPoint.address),
          when: r.scheduledAt,
        ),
      );

  /// Linha de apoio do compartilhamento: "📍 Cidade · 17/09/2026".
  /// Vazia quando não há nem lugar nem data.
  static String? subtitle({String? city, DateTime? when}) {
    final parts = [
      if (city != null && city.trim().isNotEmpty) city.trim(),
      if (when != null)
        '${when.day.toString().padLeft(2, '0')}/'
            '${when.month.toString().padLeft(2, '0')}/${when.year}',
    ];
    return parts.isEmpty ? null : '📍 ${parts.join(' · ')}';
  }
}
