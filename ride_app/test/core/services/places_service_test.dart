// Testes da extensão BusinessCategoryX. Não depende de rede — só testa
// o mapeamento enum → (label, googleType, keyword) usado pela tela
// BusinessesScreen para montar requests ao Google Places.
//
// Proteje contra: alguém adicionar uma nova categoria no enum e esquecer
// de estender os switches, ou mudar um valor sem querer.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/places_service.dart';

void main() {
  group('BusinessCategoryX.label', () {
    test('retorna o rótulo em português para cada categoria', () {
      expect(BusinessCategory.gasStation.label, 'Postos');
      expect(BusinessCategory.mechanic.label, 'Oficinas');
      expect(BusinessCategory.tireShop.label, 'Borracharias');
      expect(BusinessCategory.carWash.label, 'Lava-rápido');
    });

    test('cobre todas as categorias do enum', () {
      for (final c in BusinessCategory.values) {
        expect(c.label, isNotEmpty,
            reason: 'Categoria $c está sem label — atualize o switch');
      }
    });
  });

  group('BusinessCategoryX.googleType', () {
    test('mapeia para o type oficial do Google Places quando existe', () {
      expect(BusinessCategory.gasStation.googleType, 'gas_station');
      expect(BusinessCategory.mechanic.googleType, 'car_repair');
      expect(BusinessCategory.carWash.googleType, 'car_wash');
    });

    test('tireShop fica sem type (usa keyword porque Google não tem)', () {
      expect(BusinessCategory.tireShop.googleType, isNull);
    });
  });

  group('BusinessCategoryX.keyword', () {
    test('tireShop usa "borracharia" como keyword de busca', () {
      expect(BusinessCategory.tireShop.keyword, 'borracharia');
    });

    test('categorias com googleType próprio não precisam de keyword', () {
      expect(BusinessCategory.gasStation.keyword, isNull);
      expect(BusinessCategory.mechanic.keyword, isNull);
      expect(BusinessCategory.carWash.keyword, isNull);
    });

    test('pelo menos um entre googleType ou keyword sempre está preenchido',
        () {
      // Invariante: uma query precisa de pelo menos um filtro, senão pega
      // qualquer lugar próximo — teste protege contra adicionar categoria
      // sem filtro nenhum.
      for (final c in BusinessCategory.values) {
        final hasFilter = c.googleType != null || c.keyword != null;
        expect(hasFilter, isTrue,
            reason: 'Categoria $c não tem googleType nem keyword');
      }
    });
  });
}
