import 'package:share_plus/share_plus.dart';
import '../constants/app_links.dart';
import '../models/event_model.dart';

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
  static Future<void> shareEvent(EventModel e) {
    final d = e.startsAt;
    final when =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final local = [
      if ((e.city ?? '').isNotEmpty) e.city!,
      when,
    ].where((s) => s.isNotEmpty).join(' · ');
    return shareLink(
      title: 'Evento no RideApp: ${e.title}',
      url: AppLinks.event(e.id),
      extra: local.isNotEmpty ? '📍 $local' : null,
    );
  }
}
