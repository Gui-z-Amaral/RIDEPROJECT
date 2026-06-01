/// Categorias de comércio usadas no perfil empresa (tipo de estabelecimento)
/// e como "paradas de interesse" no perfil pessoal. Cada item tem um [id]
/// estável (persistido em `profiles.business_categories`) e um [label] exibido.
class BusinessCategory {
  final String id;
  final String label;
  const BusinessCategory(this.id, this.label);
}

const Map<String, List<BusinessCategory>> businessCategoryGroups = {
  'Gastronomia': [
    BusinessCategory('restaurantes', 'Restaurantes'),
    BusinessCategory('cafes', 'Cafés'),
    BusinessCategory('padarias', 'Padarias'),
    BusinessCategory('bares', 'Bares'),
    BusinessCategory('lanchonetes', 'Lanchonetes'),
    BusinessCategory('churrascarias', 'Churrascarias'),
  ],
  'Descanso': [
    BusinessCategory('pousadas', 'Pousadas'),
    BusinessCategory('hoteis', 'Hotéis'),
    BusinessCategory('camping', 'Camping'),
    BusinessCategory('chale', 'Chalé'),
    BusinessCategory('pernoite', 'Pernoite'),
  ],
  'Apoio na estrada': [
    BusinessCategory('borracharia', 'Borracharia'),
    BusinessCategory('posto_combustivel', 'Posto de Combustível'),
    BusinessCategory('farmacia', 'Farmácia'),
    BusinessCategory('oficina_mecanica', 'Oficina Mecânica'),
    BusinessCategory('conveniencia', 'Conveniência'),
  ],
  'Turismo e lazer': [
    BusinessCategory('mirantes', 'Mirantes'),
    BusinessCategory('cachoeira', 'Cachoeira'),
    BusinessCategory('canion', 'Cânion'),
    BusinessCategory('trilhas', 'Trilhas'),
    BusinessCategory('museu', 'Museu'),
    BusinessCategory('monumento', 'Monumento'),
    BusinessCategory('centro_historico', 'Centro Histórico'),
    BusinessCategory('parque_turistico', 'Parque Turístico'),
  ],
};

/// Map de [id] → [label] para resolver rapidamente o texto exibido a partir
/// dos ids salvos no banco.
final Map<String, String> businessCategoryLabels = {
  for (final group in businessCategoryGroups.values)
    for (final cat in group) cat.id: cat.label,
};

/// Resolve uma lista de ids em labels exibíveis (ignora ids desconhecidos).
List<String> resolveBusinessCategoryLabels(List<String> ids) {
  return ids
      .map((id) => businessCategoryLabels[id])
      .whereType<String>()
      .toList();
}
