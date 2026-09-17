import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/constants/app_links.dart';
import 'package:ride_app/core/models/share_preview.dart';
import 'package:ride_app/core/utils/share_utils.dart';

void main() {
  group('AppLinks', () {
    test('os links apontam para o PWA, não para o site antigo', () {
      expect(AppLinks.base, 'https://app.ride.dev.br');
      expect(AppLinks.event('abc'), 'https://app.ride.dev.br/e/abc');
      expect(AppLinks.trip('abc'), 'https://app.ride.dev.br/v/abc');
      expect(AppLinks.ride('abc'), 'https://app.ride.dev.br/r/abc');
    });
  });

  group('AppLinks.safeNext', () {
    test('aceita caminho interno', () {
      expect(AppLinks.safeNext('/e/123'), '/e/123');
    });

    test('sem next cai na home', () {
      expect(AppLinks.safeNext(null), '/home');
      expect(AppLinks.safeNext(''), '/home');
    });

    test('recusa URL absoluta (open redirect)', () {
      expect(AppLinks.safeNext('https://site-falso.com/x'), '/home');
      expect(AppLinks.safeNext('http://site-falso.com'), '/home');
    });

    test('recusa URL protocol-relative, que também sai do domínio', () {
      expect(AppLinks.safeNext('//site-falso.com/x'), '/home');
      expect(AppLinks.safeNext(r'/\site-falso.com'), '/home');
    });

    test('respeita o fallback informado', () {
      expect(AppLinks.safeNext(null, fallback: '/events'), '/events');
    });
  });

  group('AppLinks.oauthReturnUrl', () {
    // Na web o Google recarrega a pagina inteira: o destino precisa ir no
    // proprio redirect, senao a pessoa entra e cai na home.
    const origin = 'https://app.ride.dev.br';

    test('mantem o caminho do conteudo compartilhado', () {
      expect(AppLinks.oauthReturnUrl(origin, '/v/abc123'),
          'https://app.ride.dev.br/v/abc123');
    });

    test('sem destino volta para a home', () {
      expect(AppLinks.oauthReturnUrl(origin, null),
          'https://app.ride.dev.br/home');
    });

    test('destino forjado nao leva para fora do app', () {
      expect(AppLinks.oauthReturnUrl(origin, 'https://site-falso.com'),
          'https://app.ride.dev.br/home');
      expect(AppLinks.oauthReturnUrl(origin, '//site-falso.com'),
          'https://app.ride.dev.br/home');
    });
  });

  group('ShareKind', () {
    test('cada tipo tem o segmento da URL curta', () {
      expect(ShareKind.event.path, 'e');
      expect(ShareKind.trip.path, 'v');
      expect(ShareKind.ride.path, 'r');
    });

    test('ida e volta entre tipo e segmento', () {
      for (final k in ShareKind.values) {
        expect(ShareKindX.fromPath(k.path), k);
      }
      expect(ShareKindX.fromPath('x'), isNull);
    });
  });

  group('SharePreview.cityFromAddress', () {
    test('extrai "Cidade - UF" de um endereço completo do Google', () {
      expect(
        SharePreview.cityFromAddress(
            'Rod. Interpraias, 848 - Praia do Rosa, Imbituba - SC, '
            '88780-000, Brasil'),
        'Imbituba - SC',
      );
    });

    test('não devolve a rua quando não há cidade identificável', () {
      // Sem o trecho "Cidade - UF" não dá para saber a cidade: melhor nada do
      // que expor a rua de alguém.
      expect(SharePreview.cityFromAddress('Rua das Flores, 100'), isNull);
    });

    test('funciona com endereço curto só com cidade e UF', () {
      expect(SharePreview.cityFromAddress('Garopaba - SC'), 'Garopaba - SC');
    });

    test('null e vazio devolvem null', () {
      expect(SharePreview.cityFromAddress(null), isNull);
      expect(SharePreview.cityFromAddress(''), isNull);
      expect(SharePreview.cityFromAddress('   '), isNull);
    });

    test('ignora o país e pega a cidade', () {
      expect(
        SharePreview.cityFromAddress('Av. Beira Mar, Florianópolis - SC, Brasil'),
        'Florianópolis - SC',
      );
    });
  });

  group('ShareUtils.subtitle', () {
    test('junta cidade e data', () {
      expect(
        ShareUtils.subtitle(city: 'Imbituba - SC', when: DateTime(2026, 9, 17)),
        '📍 Imbituba - SC · 17/09/2026',
      );
    });

    test('só data quando não há cidade', () {
      expect(ShareUtils.subtitle(when: DateTime(2026, 1, 5)), '📍 05/01/2026');
    });

    test('só cidade quando não há data', () {
      expect(ShareUtils.subtitle(city: 'Garopaba - SC'), '📍 Garopaba - SC');
    });

    test('sem nada devolve null (não manda linha vazia)', () {
      expect(ShareUtils.subtitle(), isNull);
      expect(ShareUtils.subtitle(city: '  '), isNull);
    });
  });
}
