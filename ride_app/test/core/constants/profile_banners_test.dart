// Testes do catálogo de banners predefinidos (contas pessoais) e do
// helper que distingue preset (id) de upload (URL, contas empresa).
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/constants/profile_banners.dart';

void main() {
  group('profileBannerPresets', () {
    test('tem os 4 presets iniciais pedidos', () {
      final ids = profileBannerPresets.map((p) => p.id).toSet();
      expect(ids, {'cherry_blossom', 'cyber', 'motorcycles', 'skulls'});
    });

    test('todos os ids são únicos', () {
      final ids = profileBannerPresets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('nenhum preset é premium hoje (fase gratuita)', () {
      expect(profileBannerPresets.every((p) => !p.isPremium), isTrue);
    });

    test('todo preset aponta para um asset dentro de assets/images/banners/',
        () {
      for (final p in profileBannerPresets) {
        expect(p.assetPath, startsWith('assets/images/banners/'),
            reason: '${p.id} com assetPath fora do padrão');
      }
    });
  });

  group('profileBannerPresetById', () {
    test('encontra o preset pelo id', () {
      expect(profileBannerPresetById('motorcycles')?.label, 'Motos');
    });

    test('id nulo ou desconhecido (ex: URL de empresa) retorna null', () {
      expect(profileBannerPresetById(null), isNull);
      expect(profileBannerPresetById('https://x/banner.jpg'), isNull);
      expect(profileBannerPresetById('nao-existe'), isNull);
    });
  });

  group('isBannerUrl', () {
    test('URLs http(s) são reconhecidas como upload', () {
      expect(isBannerUrl('https://x/banner.jpg'), isTrue);
      expect(isBannerUrl('http://x/banner.jpg'), isTrue);
    });

    test('id de preset não é URL', () {
      expect(isBannerUrl('motorcycles'), isFalse);
    });

    test('nulo não é URL', () {
      expect(isBannerUrl(null), isFalse);
    });
  });
}
