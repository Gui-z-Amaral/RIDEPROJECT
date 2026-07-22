// Testes do catálogo de molduras e da paleta de cores da personalização de
// perfil. Cobre a resolução de ids -> Color e os fallbacks para o padrão.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/constants/profile_appearance.dart';

void main() {
  group('avatarFrames', () {
    test('primeira entrada é "none" (sem moldura)', () {
      expect(avatarFrames.first.id, 'none');
      expect(avatarFrames.first.colors, isEmpty);
    });

    test('todos os ids são únicos', () {
      final ids = avatarFrames.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('nenhuma moldura é premium hoje (fase gratuita)', () {
      expect(avatarFrames.every((f) => !f.isPremium), isTrue);
    });

    test('molduras diferentes de "none" têm pelo menos 1 cor', () {
      for (final f in avatarFrames.where((f) => f.id != 'none')) {
        expect(f.colors, isNotEmpty, reason: '${f.id} sem cor');
      }
    });
  });

  group('avatarFrameById', () {
    test('encontra a moldura pelo id', () {
      final f = avatarFrameById('gold');
      expect(f.id, 'gold');
    });

    test('id desconhecido ou nulo cai para "none"', () {
      expect(avatarFrameById('inexistente').id, 'none');
      expect(avatarFrameById(null).id, 'none');
    });
  });

  group('profileColorPalette', () {
    test('tem as 5 cores pedidas: preto, ciano, verde claro, roxo claro, branco',
        () {
      final ids = profileColorPalette.map((c) => c.id).toSet();
      expect(
        ids,
        {'black', 'cyan', 'light_green', 'light_purple', 'white'},
      );
    });

    test('branco é exatamente 0xFFFFFFFF', () {
      final white =
          profileColorPalette.firstWhere((c) => c.id == 'white');
      expect(white.color, const Color(0xFFFFFFFF));
    });
  });

  group('resolveProfileColor', () {
    test('id nulo retorna o fallback', () {
      final result = resolveProfileColor(null, Colors.red);
      expect(result, Colors.red);
    });

    test('id válido retorna a cor da paleta', () {
      final result = resolveProfileColor('cyan', Colors.red);
      final expected =
          profileColorPalette.firstWhere((c) => c.id == 'cyan').color;
      expect(result, expected);
    });

    test('id desconhecido cai para o fallback (não quebra)', () {
      final result = resolveProfileColor('cor-que-nao-existe', Colors.red);
      expect(result, Colors.red);
    });
  });

  group('isLightColor', () {
    test('branco é claro', () {
      expect(isLightColor(const Color(0xFFFFFFFF)), isTrue);
    });

    test('preto não é claro', () {
      expect(isLightColor(const Color(0xFF000000)), isFalse);
    });
  });
}
