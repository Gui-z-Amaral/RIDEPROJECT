// Testes das constantes de categorias de comércio. Os ids são persistidos em
// profiles.business_categories, então precisam ser estáveis e o mapa de
// id→label tem que cobrir todos os grupos.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/constants/business_categories.dart';

void main() {
  group('businessCategoryGroups', () {
    test('tem os 4 grupos esperados do Figma', () {
      expect(
        businessCategoryGroups.keys,
        containsAll(<String>[
          'Gastronomia',
          'Descanso',
          'Apoio na estrada',
          'Turismo e lazer',
        ]),
      );
    });

    test('nenhum grupo está vazio', () {
      for (final entry in businessCategoryGroups.entries) {
        expect(entry.value, isNotEmpty, reason: 'grupo ${entry.key} vazio');
      }
    });

    test('todos os ids são únicos entre todos os grupos', () {
      final ids = <String>[];
      for (final group in businessCategoryGroups.values) {
        for (final cat in group) {
          ids.add(cat.id);
        }
      }
      expect(ids.toSet().length, ids.length,
          reason: 'há ids de categoria duplicados');
    });

    test('ids usam snake_case sem espaços nem maiúsculas', () {
      final pattern = RegExp(r'^[a-z0-9_]+$');
      for (final group in businessCategoryGroups.values) {
        for (final cat in group) {
          expect(pattern.hasMatch(cat.id), isTrue,
              reason: 'id inválido: ${cat.id}');
          expect(cat.label, isNotEmpty);
        }
      }
    });
  });

  group('businessCategoryLabels', () {
    test('mapeia todo id para o label correspondente', () {
      // Conta o total de categorias e confere que o mapa tem o mesmo tamanho.
      final total = businessCategoryGroups.values
          .fold<int>(0, (sum, g) => sum + g.length);
      expect(businessCategoryLabels.length, total);
      expect(businessCategoryLabels['posto_combustivel'], 'Posto de Combustível');
      expect(businessCategoryLabels['restaurantes'], 'Restaurantes');
    });
  });

  group('resolveBusinessCategoryLabels', () {
    test('resolve ids conhecidos preservando a ordem de entrada', () {
      final labels =
          resolveBusinessCategoryLabels(['cafes', 'oficina_mecanica']);
      expect(labels, ['Cafés', 'Oficina Mecânica']);
    });

    test('ignora ids desconhecidos silenciosamente', () {
      final labels = resolveBusinessCategoryLabels(
          ['restaurantes', 'id_que_nao_existe', 'bares']);
      expect(labels, ['Restaurantes', 'Bares']);
    });

    test('lista vazia retorna lista vazia', () {
      expect(resolveBusinessCategoryLabels([]), isEmpty);
    });

    test('lista só com ids desconhecidos retorna vazio', () {
      expect(resolveBusinessCategoryLabels(['xpto', 'foo']), isEmpty);
    });
  });
}
