import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/user_model.dart';
import 'package:ride_app/core/services/supabase_auth_service.dart';

void main() {
  group('UserModel.flattenRow (migration 042)', () {
    test('traz os campos de profile_details para a raiz', () {
      final r = UserModel.flattenRow({
        'id': 'u1',
        'name': 'Gui',
        'profile_details': {'bio': 'rodando', 'city': 'Araranguá'},
      });
      expect(r['bio'], 'rodando');
      expect(r['city'], 'Araranguá');
      expect(r['name'], 'Gui');
      expect(r.containsKey('profile_details'), isFalse);
    });

    test('aceita o embed como lista', () {
      final r = UserModel.flattenRow({
        'id': 'u1',
        'profile_details': [
          {'city': 'Torres'}
        ],
      });
      expect(r['city'], 'Torres');
    });

    test('perfil privado de não-amigo: embed vazio, campos nulos', () {
      // É este o caso que faz o interruptor existir: a RLS não devolve a
      // linha, e a tela simplesmente não tem o dado.
      final u = UserModel.fromMap({
        'id': 'u1',
        'name': 'Fulano',
        'username': 'fulano',
        'profile_details': null,
      });
      expect(u.bio, isNull);
      expect(u.city, isNull);
      expect(u.motoModel, isNull);
      expect(u.name, 'Fulano');
    });

    test('embed como lista vazia também não estoura', () {
      final u = UserModel.fromMap(
          {'id': 'u1', 'name': 'F', 'username': 'f', 'profile_details': []});
      expect(u.city, isNull);
    });

    test('sem a chave, o mapa segue igual', () {
      final r = UserModel.flattenRow({'id': 'u1', 'name': 'Gui'});
      expect(r, {'id': 'u1', 'name': 'Gui'});
    });

    test('fromMap lê o perfil completo através do embed', () {
      final u = UserModel.fromMap({
        'id': 'u1',
        'name': 'Gui',
        'username': 'gui',
        'profile_details': {
          'bio': 'b',
          'city': 'c',
          'moto_model': 'XRE 300',
          'moto_year': '2022',
          'trip_style': 'Trilha',
          'photos': ['p1', 'p2'],
        },
      });
      expect(u.motoModel, 'XRE 300');
      expect(u.motoYear, '2022');
      expect(u.tripStyle, 'Trilha');
      expect(u.photos, ['p1', 'p2']);
    });
  });

  group('SupabaseAuthService.splitDetails (migration 042)', () {
    test('separa as colunas que mudaram de tabela', () {
      final updates = <String, dynamic>{
        'name': 'Gui',
        'bio': 'b',
        'city': 'Araranguá',
        'avatar_url': 'a',
      };
      final det = SupabaseAuthService.splitDetails(updates);

      expect(det, {'bio': 'b', 'city': 'Araranguá'});
      // O que sobra é o que vai para `profiles`.
      expect(updates, {'name': 'Gui', 'avatar_url': 'a'});
    });

    test('cobre as seis colunas movidas', () {
      final updates = <String, dynamic>{
        'bio': 1,
        'city': 2,
        'moto_model': 3,
        'moto_year': 4,
        'trip_style': 5,
        'photos': 6,
      };
      expect(SupabaseAuthService.splitDetails(updates).length, 6);
      expect(updates, isEmpty);
    });

    test('null é separado, não ignorado', () {
      // Limpar o estilo de viagem grava null — some se a checagem for por
      // valor em vez de por presença da chave.
      final updates = <String, dynamic>{'trip_style': null};
      final det = SupabaseAuthService.splitDetails(updates);
      expect(det.containsKey('trip_style'), isTrue);
      expect(det['trip_style'], isNull);
    });

    test('negócio continua em profiles', () {
      // `business_*` fica público de propósito: existe para ser encontrado.
      final updates = <String, dynamic>{
        'business_name': 'Posto X',
        'business_address_city': 'Torres',
      };
      expect(SupabaseAuthService.splitDetails(updates), isEmpty);
      expect(updates.length, 2);
    });

    test('nada a separar devolve vazio', () {
      final updates = <String, dynamic>{'name': 'Gui'};
      expect(SupabaseAuthService.splitDetails(updates), isEmpty);
    });
  });
}
