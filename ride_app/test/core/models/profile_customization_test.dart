// Testes de ProfileCustomization: fromMap/toMap, defaults e o copyWith com
// sentinel (precisa distinguir "não mexer" de "limpar para null").
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/profile_customization.dart';

void main() {
  group('ProfileCustomization.empty', () {
    test('vem com avatarFrame "none" e cores/banner nulos', () {
      final c = ProfileCustomization.empty('u1');
      expect(c.userId, 'u1');
      expect(c.avatarFrame, 'none');
      expect(c.bannerUrl, isNull);
      expect(c.backgroundColor, isNull);
      expect(c.textColor, isNull);
      expect(c.isDefault, isTrue);
    });
  });

  group('ProfileCustomization.fromMap', () {
    test('parseia uma row completa', () {
      final c = ProfileCustomization.fromMap({
        'user_id': 'u1',
        'banner_url': 'https://x/banner.jpg',
        'avatar_frame': 'gold',
        'background_color': 'black',
        'text_color': 'white',
      });
      expect(c.userId, 'u1');
      expect(c.bannerUrl, 'https://x/banner.jpg');
      expect(c.avatarFrame, 'gold');
      expect(c.backgroundColor, 'black');
      expect(c.textColor, 'white');
      expect(c.isDefault, isFalse);
    });

    test('avatar_frame ausente vira "none"', () {
      final c = ProfileCustomization.fromMap({'user_id': 'u1'});
      expect(c.avatarFrame, 'none');
    });
  });

  group('ProfileCustomization.toMap', () {
    test('serializa todos os campos com as keys do Supabase', () {
      const c = ProfileCustomization(
        userId: 'u1',
        bannerUrl: 'b.jpg',
        avatarFrame: 'gold',
        backgroundColor: 'black',
        textColor: 'white',
      );
      final m = c.toMap();
      expect(m['banner_url'], 'b.jpg');
      expect(m['avatar_frame'], 'gold');
      expect(m['background_color'], 'black');
      expect(m['text_color'], 'white');
    });
  });

  group('ProfileCustomization.copyWith', () {
    test('sem argumentos preserva tudo', () {
      const c = ProfileCustomization(
        userId: 'u1',
        bannerUrl: 'b.jpg',
        avatarFrame: 'gold',
        backgroundColor: 'black',
        textColor: 'white',
      );
      final copy = c.copyWith();
      expect(copy.bannerUrl, 'b.jpg');
      expect(copy.avatarFrame, 'gold');
      expect(copy.backgroundColor, 'black');
      expect(copy.textColor, 'white');
    });

    test('permite LIMPAR um campo passando null explicitamente', () {
      const c = ProfileCustomization(
        userId: 'u1',
        backgroundColor: 'black',
        textColor: 'white',
      );
      // Simula o toggle "clicar de novo para remover" da tela de aparência.
      final copy = c.copyWith(backgroundColor: null);
      expect(copy.backgroundColor, isNull);
      expect(copy.textColor, 'white'); // não mexeu no outro campo
    });

    test('troca só o avatarFrame preservando o resto', () {
      const c = ProfileCustomization(userId: 'u1', backgroundColor: 'cyan');
      final copy = c.copyWith(avatarFrame: 'sunset');
      expect(copy.avatarFrame, 'sunset');
      expect(copy.backgroundColor, 'cyan');
    });
  });
}
