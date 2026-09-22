import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/supabase_social_service.dart';
import 'package:ride_app/core/utils/storage_utils.dart';

void main() {
  group('SupabaseSocialService.signatureStillValid', () {
    final agora = DateTime.utc(2026, 9, 22, 12);

    test('assinatura com folga ainda serve', () {
      expect(
        SupabaseSocialService.signatureStillValid(
            agora.add(const Duration(minutes: 30)), agora),
        isTrue,
      );
    });

    test('a menos de 5 minutos do fim já não serve', () {
      // Entregar uma URL que vence no meio do download quebra a imagem.
      expect(
        SupabaseSocialService.signatureStillValid(
            agora.add(const Duration(minutes: 4)), agora),
        isFalse,
      );
    });

    test('vencida não serve', () {
      expect(
        SupabaseSocialService.signatureStillValid(
            agora.subtract(const Duration(seconds: 1)), agora),
        isFalse,
      );
    });
  });

  group('caminho da imagem do chat (migration 043)', () {
    const base = 'https://api.ride.dev.br/storage/v1/object/public/chat-images/';

    test('a URL gravada na mensagem vira o caminho a assinar', () {
      expect(
        StorageUtils.pathFromPublicUrl(
            '${base}chat/aaa_bbb/1700000000000.jpg', 'chat-images'),
        'chat/aaa_bbb/1700000000000.jpg',
      );
    });

    test('URL de outro bucket não é tratada como imagem do chat', () {
      // Sem isto, uma URL qualquer viraria pedido de assinatura no bucket
      // errado; volta como veio.
      expect(
        StorageUtils.pathFromPublicUrl(
            'https://api.ride.dev.br/storage/v1/object/public/avatars/u/a.jpg',
            'chat-images'),
        isNull,
      );
    });
  });
}
