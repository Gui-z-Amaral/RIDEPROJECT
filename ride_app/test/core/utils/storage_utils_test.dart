import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/storage_utils.dart';

void main() {
  group('StorageUtils.pathFromPublicUrl', () {
    const base =
        'https://x.supabase.co/storage/v1/object/public/avatars/uid-1/avatar_123.jpg';

    test('extrai o caminho de uma URL pública do bucket', () {
      expect(
        StorageUtils.pathFromPublicUrl(base, 'avatars'),
        'uid-1/avatar_123.jpg',
      );
    });

    test('ignora a query de cache-buster (?t=...)', () {
      expect(
        StorageUtils.pathFromPublicUrl('$base?t=999', 'avatars'),
        'uid-1/avatar_123.jpg',
      );
    });

    test('retorna null quando a URL é de outro bucket', () {
      expect(StorageUtils.pathFromPublicUrl(base, 'user-photos'), isNull);
    });

    test('retorna null para URL sem o marcador de bucket público', () {
      expect(
        StorageUtils.pathFromPublicUrl('https://exemplo.com/foto.jpg', 'avatars'),
        isNull,
      );
    });

    test('retorna null quando não há caminho após o bucket', () {
      expect(
        StorageUtils.pathFromPublicUrl(
          'https://x.supabase.co/storage/v1/object/public/avatars/',
          'avatars',
        ),
        isNull,
      );
    });
  });
}
