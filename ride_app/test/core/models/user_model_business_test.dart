// Testes dos campos de perfil EMPRESA no UserModel. Garantem que o parsing
// snake_case→camelCase dos campos business e os getters isBusiness/displayName
// funcionam, já que alternar account_type não pode perder dados.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/user_model.dart';

void main() {
  group('UserModel — account_type / isBusiness', () {
    test('account_type ausente vira "personal" e isBusiness é false', () {
      final u = UserModel.fromMap({'id': 'u1', 'name': 'x', 'username': 'x'});
      expect(u.accountType, 'personal');
      expect(u.isBusiness, isFalse);
    });

    test('account_type "business" marca isBusiness', () {
      final u = UserModel.fromMap({
        'id': 'u1',
        'name': 'x',
        'username': 'x',
        'account_type': 'business',
      });
      expect(u.accountType, 'business');
      expect(u.isBusiness, isTrue);
    });
  });

  group('UserModel — campos business no fromMap', () {
    test('parseia todos os campos business', () {
      final row = <String, dynamic>{
        'id': 'b1',
        'name': 'Dono',
        'username': 'dono',
        'account_type': 'business',
        'business_name': 'Posto do Zé',
        'business_description': 'Posto 24h na estrada',
        'business_banner_url': 'https://x/banner.jpg',
        'business_address_street': 'Av. Brasil',
        'business_address_number': '1000',
        'business_address_neighborhood': 'Centro',
        'business_address_city': 'Florianópolis',
        'business_address_state': 'SC',
        'business_categories': ['posto_combustivel', 'conveniencia'],
      };
      final u = UserModel.fromMap(row);

      expect(u.businessName, 'Posto do Zé');
      expect(u.businessDescription, 'Posto 24h na estrada');
      expect(u.businessBannerUrl, 'https://x/banner.jpg');
      expect(u.businessAddressStreet, 'Av. Brasil');
      expect(u.businessAddressNumber, '1000');
      expect(u.businessAddressNeighborhood, 'Centro');
      expect(u.businessAddressCity, 'Florianópolis');
      expect(u.businessAddressState, 'SC');
      expect(u.businessCategories, ['posto_combustivel', 'conveniencia']);
    });

    test('business_categories nulo vira lista vazia', () {
      final u = UserModel.fromMap({
        'id': 'b1',
        'name': 'x',
        'username': 'x',
        'account_type': 'business',
      });
      expect(u.businessCategories, isEmpty);
    });
  });

  group('UserModel — displayName', () {
    test('empresa com businessName usa o nome fantasia', () {
      const u = UserModel(
        id: 'b1',
        name: 'João Silva',
        username: 'joao',
        accountType: 'business',
        businessName: 'Mecânica do João',
      );
      expect(u.displayName, 'Mecânica do João');
    });

    test('empresa sem businessName cai pro nome pessoal', () {
      const u = UserModel(
        id: 'b1',
        name: 'João Silva',
        username: 'joao',
        accountType: 'business',
      );
      expect(u.displayName, 'João Silva');
    });

    test('conta pessoal sempre usa o nome pessoal mesmo com businessName', () {
      const u = UserModel(
        id: 'p1',
        name: 'João Silva',
        username: 'joao',
        businessName: 'Resquício de empresa',
      );
      expect(u.displayName, 'João Silva');
    });
  });

  group('UserModel — toMap inclui business', () {
    test('serializa campos business com as keys do Supabase', () {
      const u = UserModel(
        id: 'b1',
        name: 'Dono',
        username: 'dono',
        accountType: 'business',
        businessName: 'Posto do Zé',
        businessAddressState: 'SC',
        businessCategories: ['posto_combustivel'],
      );
      final m = u.toMap();
      expect(m['account_type'], 'business');
      expect(m['business_name'], 'Posto do Zé');
      expect(m['business_address_state'], 'SC');
      expect(m['business_categories'], ['posto_combustivel']);
    });
  });

  group('UserModel — copyWith preserva business', () {
    test('copyWith sem args mantém os campos business', () {
      const u = UserModel(
        id: 'b1',
        name: 'Dono',
        username: 'dono',
        accountType: 'business',
        businessName: 'Posto do Zé',
        businessCategories: ['posto_combustivel'],
      );
      final copy = u.copyWith(bio: 'nova bio');
      expect(copy.accountType, 'business');
      expect(copy.businessName, 'Posto do Zé');
      expect(copy.businessCategories, ['posto_combustivel']);
      expect(copy.bio, 'nova bio');
    });

    test('copyWith altera accountType quando passado', () {
      const u = UserModel(
        id: 'b1',
        name: 'Dono',
        username: 'dono',
        accountType: 'business',
      );
      final copy = u.copyWith(accountType: 'personal');
      expect(copy.isBusiness, isFalse);
    });
  });
}
