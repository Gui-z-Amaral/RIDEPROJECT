import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/maps_proxy.dart';
import 'package:ride_app/core/constants/supabase_config.dart';

void main() {
  group('MapsProxy.uri', () {
    test('aponta para a Edge Function gmaps do Supabase', () {
      final uri = MapsProxy.uri('place/textsearch/json', {'query': 'praia'});
      expect(uri.origin, Uri.parse(SupabaseConfig.url).origin);
      expect(uri.path, '/functions/v1/gmaps');
    });

    test('coloca o caminho da API no parâmetro path e mantém os demais', () {
      final uri = MapsProxy.uri('geocode/json', {
        'latlng': '-27.5,-48.5',
        'language': 'pt-BR',
      });
      expect(uri.queryParameters['path'], 'geocode/json');
      expect(uri.queryParameters['latlng'], '-27.5,-48.5');
      expect(uri.queryParameters['language'], 'pt-BR');
    });

    test('nunca envia a chave do Google na query (fica no servidor)', () {
      final uri = MapsProxy.uri('place/nearbysearch/json', {
        'location': '0,0',
        'radius': '2000',
      });
      expect(uri.queryParameters.containsKey('key'), isFalse);
    });
  });

  group('MapsProxy.headers', () {
    test('inclui apikey e Authorization com a anon key', () {
      final h = MapsProxy.headers;
      expect(h['apikey'], SupabaseConfig.anonKey);
      expect(h['Authorization'], 'Bearer ${SupabaseConfig.anonKey}');
    });
  });

  group('MapsProxy.isLegacyGooglePhotoUrl', () {
    test('detecta URL de foto salva antes do proxy (aponta pro Google)', () {
      expect(
        MapsProxy.isLegacyGooglePhotoUrl(
            'https://maps.googleapis.com/maps/api/place/photo'
            '?maxwidth=400&photo_reference=abc&key=AIza123'),
        isTrue,
      );
    });

    test('URL do proxy não é considerada legada', () {
      final atual = MapsProxy.photoUrl({
        'maxwidth': '400',
        'photo_reference': 'abc123',
      });
      expect(MapsProxy.isLegacyGooglePhotoUrl(atual), isFalse);
    });

    test('null e vazio não são legados', () {
      expect(MapsProxy.isLegacyGooglePhotoUrl(null), isFalse);
      expect(MapsProxy.isLegacyGooglePhotoUrl(''), isFalse);
    });

    test('URL do Supabase Storage não é legada', () {
      expect(
        MapsProxy.isLegacyGooglePhotoUrl(
            '${SupabaseConfig.url}/storage/v1/object/public/trip-photos/x.jpg'),
        isFalse,
      );
    });
  });

  group('MapsProxy.photoUrl', () {
    test('usa path place/photo e leva a apikey na query (pra <img>)', () {
      final uri = Uri.parse(MapsProxy.photoUrl({
        'maxwidth': '400',
        'photo_reference': 'abc123',
      }));
      expect(uri.path, '/functions/v1/gmaps');
      expect(uri.queryParameters['path'], 'place/photo');
      expect(uri.queryParameters['photo_reference'], 'abc123');
      expect(uri.queryParameters['maxwidth'], '400');
      expect(uri.queryParameters['apikey'], SupabaseConfig.anonKey);
      expect(uri.queryParameters.containsKey('key'), isFalse);
    });
  });
}
