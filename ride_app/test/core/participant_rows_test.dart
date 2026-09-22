import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/participant_rows.dart';

void main() {
  const criador = 'u-criador';

  group('ParticipantRows.invitedIds', () {
    test('tira o criador da lista de convidados', () {
      // O criador entra num INSERT separado: se voltasse aqui, a chave
      // primária (trip_id, user_id) estouraria e a viagem não salvava.
      expect(ParticipantRows.invitedIds(criador, [criador, 'a', 'b']),
          ['a', 'b']);
    });

    test('remove repetições, mantendo a ordem', () {
      expect(ParticipantRows.invitedIds(criador, ['b', 'a', 'b']), ['b', 'a']);
    });

    test('ignora id vazio', () {
      expect(ParticipantRows.invitedIds(criador, ['', 'a']), ['a']);
    });

    test('lista só com o criador não convida ninguém', () {
      expect(ParticipantRows.invitedIds(criador, [criador]), isEmpty);
      expect(ParticipantRows.invitedIds(criador, []), isEmpty);
    });
  });

  group('ParticipantRows.invitedRows', () {
    test('monta a linha com a chave estrangeira certa', () {
      final rows = ParticipantRows.invitedRows(
        fkColumn: 'trip_id',
        parentId: 't1',
        creatorId: criador,
        participantIds: ['a'],
      );
      expect(rows, [
        {'trip_id': 't1', 'user_id': 'a', 'status': 'waiting'},
      ]);
    });

    test('rolê usa ride_id', () {
      final rows = ParticipantRows.invitedRows(
        fkColumn: 'ride_id',
        parentId: 'r1',
        creatorId: criador,
        participantIds: ['a'],
      );
      expect(rows.single['ride_id'], 'r1');
    });

    test('convite nasce sempre pendente', () {
      // A policy da migration 040 só aceita linha de terceiro com
      // status 'waiting' — quem confirma é a própria pessoa.
      final rows = ParticipantRows.invitedRows(
        fkColumn: 'trip_id',
        parentId: 't1',
        creatorId: criador,
        participantIds: ['a', 'b', criador],
      );
      expect(rows.length, 2);
      expect(rows.every((r) => r['status'] == 'waiting'), isTrue);
    });

    test('sem convidados devolve lista vazia', () {
      expect(
        ParticipantRows.invitedRows(
          fkColumn: 'trip_id',
          parentId: 't1',
          creatorId: criador,
          participantIds: [criador],
        ),
        isEmpty,
      );
    });
  });
}
