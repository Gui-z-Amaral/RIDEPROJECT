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
}
