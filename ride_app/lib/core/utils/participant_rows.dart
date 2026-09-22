/// Monta as linhas de participante de uma viagem ou rolê recém-criado.
///
/// Existe porque a premissa errada que quebrou o convite morava aqui: o app
/// mandava criador e convidados num INSERT só, e a RLS rejeita o lote inteiro
/// quando uma das linhas é de outra pessoa (migration 040). Separar as duas
/// listas é o que permite o criador entrar sempre, e o convite falhar visível
/// se falhar.
///
/// [creatorId] nunca aparece em [invitedRows], mesmo que venha repetido na
/// lista de convidados — era esse duplicado que estourava a chave primária.
class ParticipantRows {
  const ParticipantRows._();

  /// Quem foi convidado, sem o criador e sem repetições, na ordem de entrada.
  static List<String> invitedIds(String creatorId, List<String> participantIds) {
    final seen = <String>{creatorId};
    final out = <String>[];
    for (final id in participantIds) {
      if (id.isEmpty) continue;
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  /// As linhas do INSERT dos convidados. [fkColumn] é `trip_id` ou `ride_id`.
  ///
  /// `status: 'waiting'` vai explícito: a policy da 040 só deixa o criador
  /// inserir linha de terceiro se ela nascer pendente — quem confirma é a
  /// própria pessoa.
  static List<Map<String, dynamic>> invitedRows({
    required String fkColumn,
    required String parentId,
    required String creatorId,
    required List<String> participantIds,
  }) =>
      invitedIds(creatorId, participantIds)
          .map((id) => {
                fkColumn: parentId,
                'user_id': id,
                'status': 'waiting',
              })
          .toList();
}
