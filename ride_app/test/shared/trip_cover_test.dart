import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/location_model.dart';
import 'package:ride_app/core/services/maps_proxy.dart';
import 'package:ride_app/shared/widgets/trip_cover.dart';

void main() {
  group('TripCover.usableSavedCover', () {
    test('aceita URL do proxy gmaps', () {
      final url = MapsProxy.photoUrl({
        'maxwidth': '400',
        'photo_reference': 'abc123',
      });
      expect(TripCover.usableSavedCover(url), url);
    });

    test('aceita URL do Supabase Storage', () {
      const url = 'https://exemplo.com/storage/v1/object/public/trips/x.jpg';
      expect(TripCover.usableSavedCover(url), url);
    });

    test('descarta capa antiga que aponta direto pro Google (quebra na web)',
        () {
      expect(
        TripCover.usableSavedCover(
            'https://maps.googleapis.com/maps/api/place/photo'
            '?maxwidth=400&photo_reference=abc&key=AIza123'),
        isNull,
      );
    });

    test('null e vazio não são capa utilizável', () {
      expect(TripCover.usableSavedCover(null), isNull);
      expect(TripCover.usableSavedCover(''), isNull);
    });
  });

  group('TripCover.coverQuery', () {
    LocationModel loc({String? label, String? address}) =>
        LocationModel(lat: -27.5, lng: -48.5, label: label, address: address);

    test('prefere o nome do lugar quando existe', () {
      expect(
        TripCover.coverQuery(
            loc(label: 'Praia do Rosa', address: 'Rod. Interpraias, 848')),
        'Praia do Rosa',
      );
    });

    test('cai no endereço quando não há nome', () {
      expect(
        TripCover.coverQuery(loc(address: 'Rod. Interpraias, 848')),
        'Rod. Interpraias, 848',
      );
    });

    test('nome só com espaços não conta como nome', () {
      expect(
        TripCover.coverQuery(loc(label: '   ', address: 'Rod. Interpraias')),
        'Rod. Interpraias',
      );
    });

    test('tira espaços das pontas', () {
      expect(TripCover.coverQuery(loc(label: '  Garopaba  ')), 'Garopaba');
    });

    test('sem nome e sem endereço devolve vazio (não dá pra buscar)', () {
      expect(TripCover.coverQuery(loc()), '');
      expect(TripCover.coverQuery(loc(label: '', address: '')), '');
    });
  });
}
