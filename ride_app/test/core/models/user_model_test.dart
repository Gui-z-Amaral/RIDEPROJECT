// Testes de UserModel — especialmente do factory fromMap, que é a ponte
// entre os services (Supabase) e o resto do app. Se esse parsing quebra
// em silêncio, várias telas exibem dados vazios sem levantar erro.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/user_model.dart';

void main() {
  group('UserModel.fromMap', () {
    test('parseia uma row completa do Supabase', () {
      final row = <String, dynamic>{
        'id': 'u-123',
        'name': 'Guilherme',
        'username': 'gui_z',
        'avatar_url': 'https://example.com/a.jpg',
        'bio': 'Andando de moto',
        'city': 'Florianópolis, SC',
        'moto_model': 'MT-07',
        'moto_year': '2023',
        'trip_style': 'Longas',
        'photos': ['p1.jpg', 'p2.jpg'],
        'friends_count': 42,
        'trips_count': 10,
        'is_online': true,
        'created_at': '2025-01-09T14:30:00Z',
      };
      final u = UserModel.fromMap(row);

      expect(u.id, 'u-123');
      expect(u.name, 'Guilherme');
      expect(u.username, 'gui_z');
      expect(u.avatarUrl, 'https://example.com/a.jpg');
      expect(u.bio, 'Andando de moto');
      expect(u.city, 'Florianópolis, SC');
      expect(u.motoModel, 'MT-07');
      expect(u.motoYear, '2023');
      expect(u.tripStyle, 'Longas');
      expect(u.photos, ['p1.jpg', 'p2.jpg']);
      expect(u.friendsCount, 42);
      expect(u.tripsCount, 10);
      expect(u.isOnline, isTrue);
      expect(u.createdAt, isNotNull);
      expect(u.createdAt!.year, 2025);
    });

    test('tolera campos nulos/ausentes sem explodir', () {
      // Simula uma linha vinda de uma query com select parcial (ex: trip
      // participant join que só trouxe id/name/avatar).
      final row = <String, dynamic>{
        'id': 'u-456',
        'name': 'Ana',
        'username': null,
      };
      final u = UserModel.fromMap(row);

      expect(u.id, 'u-456');
      expect(u.name, 'Ana');
      expect(u.username, '');
      expect(u.avatarUrl, isNull);
      expect(u.bio, isNull);
      expect(u.tripStyle, isNull);
      expect(u.photos, isEmpty);
      expect(u.friendsCount, 0);
      expect(u.tripsCount, 0);
      expect(u.isOnline, isFalse);
      expect(u.createdAt, isNull);
    });

    test('created_at aceita tanto String ISO quanto DateTime', () {
      final asString = UserModel.fromMap({
        'id': 'u-1',
        'name': 'x',
        'username': 'x',
        'created_at': '2025-01-09T00:00:00Z',
      });
      final asDateTime = UserModel.fromMap({
        'id': 'u-2',
        'name': 'x',
        'username': 'x',
        'created_at': DateTime.utc(2025, 1, 9),
      });

      expect(asString.createdAt, isNotNull);
      expect(asDateTime.createdAt, isNotNull);
      expect(asString.createdAt!.toUtc().year, 2025);
      expect(asDateTime.createdAt!.toUtc().year, 2025);
    });

    test('photos nulo vira lista vazia', () {
      final u = UserModel.fromMap({
        'id': 'u-1',
        'name': 'x',
        'username': 'x',
        'photos': null,
      });
      expect(u.photos, isEmpty);
    });

    test('contagens numéricas aceitam int ou double do Postgres', () {
      // Postgres pode retornar contagens como num; testa coerção.
      final u = UserModel.fromMap({
        'id': 'u-1',
        'name': 'x',
        'username': 'x',
        'friends_count': 12.0,
        'trips_count': 3,
      });
      expect(u.friendsCount, 12);
      expect(u.tripsCount, 3);
    });

    test('row totalmente vazia retorna um UserModel com defaults seguros', () {
      final u = UserModel.fromMap({});
      expect(u.id, '');
      expect(u.name, '');
      expect(u.username, '');
      expect(u.photos, isEmpty);
      expect(u.friendsCount, 0);
    });
  });

  group('UserModel.toMap', () {
    test('serializa todos os campos com as keys do Supabase', () {
      const u = UserModel(
        id: 'u-1',
        name: 'Guilherme',
        username: 'gui',
        avatarUrl: 'a.jpg',
        bio: 'b',
        city: 'c',
        motoModel: 'MT-07',
        motoYear: '2023',
        tripStyle: 'Curtas',
        photos: ['p1.jpg'],
        friendsCount: 5,
        tripsCount: 2,
        isOnline: true,
      );
      final m = u.toMap();
      expect(m['id'], 'u-1');
      expect(m['avatar_url'], 'a.jpg');
      expect(m['moto_model'], 'MT-07');
      expect(m['trip_style'], 'Curtas');
      expect(m['photos'], ['p1.jpg']);
      expect(m['friends_count'], 5);
      expect(m['is_online'], isTrue);
    });
  });

  group('UserModel.copyWith', () {
    test('altera apenas os campos passados e preserva os demais', () {
      const original = UserModel(
        id: 'u-1',
        name: 'Ana',
        username: 'ana',
        tripStyle: 'Curtas',
        friendsCount: 3,
      );
      final copy = original.copyWith(name: 'Ana Maria', tripStyle: 'Longas');

      expect(copy.id, 'u-1'); // id é imutável via copyWith
      expect(copy.name, 'Ana Maria');
      expect(copy.username, 'ana');
      expect(copy.tripStyle, 'Longas');
      expect(copy.friendsCount, 3);
    });
  });
}
