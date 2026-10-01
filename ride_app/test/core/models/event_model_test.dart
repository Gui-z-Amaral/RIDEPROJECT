// Testes do EventModel e seus sub-modelos (programação, patrocinadores). O
// fromMap é a ponte entre o SupabaseEventService e as telas de evento; se o
// parsing das listas aninhadas (schedule/sponsors/participants) quebra, o
// detalhe do evento aparece vazio sem erro.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/location_model.dart';
import 'package:ride_app/core/services/supabase_event_service.dart' show EventDeparture;
import 'package:ride_app/core/models/event_model.dart';

void main() {
  // Row "completa" reutilizada em vários testes.
  Map<String, dynamic> fullRow() => {
        'id': 'e1',
        'creator_id': 'b1',
        'creator': {
          'id': 'b1',
          'name': 'Dono',
          'username': 'dono',
          'account_type': 'business',
          'business_name': 'Moto Clube SC',
        },
        'title': 'Encontro de Motociclistas',
        'description': 'Grande encontro anual',
        'banner_url': 'https://x/banner.jpg',
        'lat': -27.5954,
        'lng': -48.5480,
        'address': 'Av. Beira Mar, Centro, Florianópolis',
        'location_label': 'Beira Mar Norte',
        'state_uf': 'SC',
        'city': 'Florianópolis',
        'starts_at': '2026-07-10T18:00:00Z',
        'ends_at': '2026-07-10T23:00:00Z',
        'interests_count': 42,
        'schedule': [
          {'id': 's2', 'position': 1, 'time_label': '20:00', 'title': 'Show'},
          {
            'id': 's1',
            'position': 0,
            'time_label': '18:00',
            'title': 'Abertura',
            'description': 'Abertura dos portões'
          },
        ],
        'sponsors': [
          {'id': 'sp2', 'position': 1, 'name': 'Oficina X'},
          {
            'id': 'sp1',
            'position': 0,
            'name': 'Posto Y',
            'logo_url': 'https://x/logo.png'
          },
        ],
        'participants': [
          {
            'user': {'id': 'u9', 'name': 'Ana', 'username': 'ana'}
          },
          {
            'user': {'id': 'u8', 'name': 'Beto', 'username': 'beto'}
          },
        ],
      };

  group('EventModel.fromMap', () {
    test('parseia campos escalares e o criador aninhado', () {
      final e = EventModel.fromMap(fullRow());
      expect(e.id, 'e1');
      expect(e.creatorId, 'b1');
      expect(e.creator, isNotNull);
      expect(e.creator!.displayName, 'Moto Clube SC');
      expect(e.title, 'Encontro de Motociclistas');
      expect(e.bannerUrl, 'https://x/banner.jpg');
      expect(e.stateUf, 'SC');
      expect(e.city, 'Florianópolis');
      expect(e.interestsCount, 42);
      expect(e.startsAt.toUtc().year, 2026);
      expect(e.endsAt, isNotNull);
    });

    test('schedule é ordenado por position (independe da ordem da row)', () {
      final e = EventModel.fromMap(fullRow());
      expect(e.schedule.length, 2);
      expect(e.schedule.first.title, 'Abertura'); // position 0 primeiro
      expect(e.schedule.first.timeLabel, '18:00');
      expect(e.schedule.last.title, 'Show'); // position 1
    });

    test('sponsors é ordenado por position', () {
      final e = EventModel.fromMap(fullRow());
      expect(e.sponsors.length, 2);
      expect(e.sponsors.first.name, 'Posto Y'); // position 0
      expect(e.sponsors.first.logoUrl, 'https://x/logo.png');
      expect(e.sponsors.last.name, 'Oficina X');
      expect(e.sponsors.last.logoUrl, isNull);
    });

    test('participants extrai o perfil de dentro de {user: {...}}', () {
      final e = EventModel.fromMap(fullRow());
      expect(e.participants.length, 2);
      expect(e.participants.map((p) => p.name), containsAll(['Ana', 'Beto']));
    });

    test('descarta participant sem perfil válido (user vazio)', () {
      final row = fullRow();
      row['participants'] = [
        {'user': null},
        {'user': {'id': '', 'name': '', 'username': ''}},
        {
          'user': {'id': 'u1', 'name': 'Válido', 'username': 'v'}
        },
      ];
      final e = EventModel.fromMap(row);
      expect(e.participants.length, 1);
      expect(e.participants.first.name, 'Válido');
    });

    test('isInterested vem do parâmetro, default false', () {
      final row = fullRow();
      expect(EventModel.fromMap(row).isInterested, isFalse);
      expect(EventModel.fromMap(row, isInterested: true).isInterested, isTrue);
    });

    test('starts_at é convertido para horário local', () {
      final e = EventModel.fromMap(fullRow());
      expect(e.startsAt.isUtc, isFalse);
    });

    test('listas aninhadas ausentes viram listas vazias', () {
      final e = EventModel.fromMap({
        'id': 'e2',
        'creator_id': 'b1',
        'title': 'Mínimo',
        'starts_at': '2026-01-01T10:00:00Z',
      });
      expect(e.schedule, isEmpty);
      expect(e.sponsors, isEmpty);
      expect(e.participants, isEmpty);
      expect(e.creator, isNull);
      expect(e.interestsCount, 0);
    });
  });

  group('EventModel — hasLocation / googleMapsUrl', () {
    test('com lat/lng hasLocation é true e url usa coordenadas', () {
      final e = EventModel.fromMap(fullRow());
      expect(e.hasLocation, isTrue);
      expect(e.googleMapsUrl, contains('-27.5954,-48.548'));
    });

    test('sem lat/lng usa busca por texto', () {
      final e = EventModel.fromMap({
        'id': 'e3',
        'creator_id': 'b1',
        'title': 'Sem coords',
        'location_label': 'Praça Central',
        'starts_at': '2026-01-01T10:00:00Z',
      });
      expect(e.hasLocation, isFalse);
      expect(e.googleMapsUrl, contains('query='));
      expect(e.googleMapsUrl, contains('Pra')); // "Praça" url-encoded
    });
  });

  group('EventModel.copyWith', () {
    test('atualiza interesse/contador e preserva o resto', () {
      final e = EventModel.fromMap(fullRow());
      final copy = e.copyWith(isInterested: true, interestsCount: 43);
      expect(copy.id, 'e1');
      expect(copy.title, e.title);
      expect(copy.isInterested, isTrue);
      expect(copy.interestsCount, 43);
      expect(copy.schedule.length, 2); // preservado
    });
  });

  group('EventScheduleItem', () {
    test('fromMap parseia e toInsertMap injeta o event_id', () {
      final item = EventScheduleItem.fromMap({
        'id': 's1',
        'position': 2,
        'time_label': '15:30',
        'title': 'Palestra',
        'description': 'Sobre manutenção',
      });
      expect(item.position, 2);
      expect(item.timeLabel, '15:30');
      expect(item.title, 'Palestra');

      final map = item.toInsertMap('e1');
      expect(map['event_id'], 'e1');
      expect(map['title'], 'Palestra');
      expect(map.containsKey('id'), isFalse); // id não vai no insert
    });
  });

  group('EventSponsor', () {
    test('fromMap parseia e toInsertMap injeta o event_id', () {
      final sp = EventSponsor.fromMap({
        'id': 'sp1',
        'position': 0,
        'name': 'Posto Y',
        'logo_url': 'https://x/logo.png',
      });
      expect(sp.name, 'Posto Y');
      expect(sp.logoUrl, 'https://x/logo.png');

      final map = sp.toInsertMap('e1');
      expect(map['event_id'], 'e1');
      expect(map['name'], 'Posto Y');
      expect(map['logo_url'], 'https://x/logo.png');
      expect(map.containsKey('id'), isFalse);
    });

    test('logo_url ausente fica nulo', () {
      final sp = EventSponsor.fromMap({'name': 'Marca'});
      expect(sp.logoUrl, isNull);
      expect(sp.name, 'Marca');
    });
  });

  group('EventModel — conclusão (migration 041)', () {
    Map<String, dynamic> linha(Map<String, dynamic> extra) => {
          'id': 'e1',
          'creator_id': 'u1',
          'title': 'Encontro',
          'starts_at': '2026-09-20T16:30:00Z',
          ...extra,
        };

    test('sem completed_at o evento está em aberto', () {
      final e = EventModel.fromMap(linha({}));
      expect(e.completedAt, isNull);
      expect(e.isCompleted, isFalse);
    });

    test('completed_at preenchido marca como concluído', () {
      final e =
          EventModel.fromMap(linha({'completed_at': '2026-09-21T10:00:00Z'}));
      expect(e.isCompleted, isTrue);
      expect(e.completedAt!.toUtc().hour, 10);
    });

    test('completed_at inválido não estoura nem conclui', () {
      final e = EventModel.fromMap(linha({'completed_at': 'nao-e-data'}));
      expect(e.isCompleted, isFalse);
    });

    test('copyWith conclui e reabre', () {
      final aberto = EventModel.fromMap(linha({}));
      final fechado = aberto.copyWith(completedAt: DateTime.utc(2026, 9, 21));
      expect(fechado.isCompleted, isTrue);
      // Reabrir é gravar null — por isso copyWith usa sentinela, e não `??`.
      expect(fechado.copyWith(completedAt: null).isCompleted, isFalse);
    });

    test('copyWith sem tocar no campo preserva a conclusão', () {
      final fechado =
          EventModel.fromMap(linha({'completed_at': '2026-09-21T10:00:00Z'}));
      expect(fechado.copyWith(isInterested: true).isCompleted, isTrue);
    });

    test('copyWith preserva clubId e isPublic', () {
      // Eles ficavam de fora: marcar interesse num evento de motoclube
      // privado o transformava, na memória, em evento solto e público.
      final e = EventModel.fromMap(
          linha({'club_id': 'c1', 'is_public': false}));
      final depois = e.copyWith(isInterested: true);
      expect(depois.clubId, 'c1');
      expect(depois.isPublic, isFalse);
    });
  });

  group('EventModel — saída do rolê (migration 046)', () {
    Map<String, dynamic> linha(Map<String, dynamic> extra) => {
          'id': 'e1',
          'creator_id': 'u1',
          'title': 'Rolê MR MOTOR SHOW',
          'starts_at': '2026-09-20T16:30:00Z',
          ...extra,
        };

    test('sem colunas de saída, não há saída', () {
      final e = EventModel.fromMap(linha({}));
      expect(e.hasDeparture, isFalse);
      expect(e.meetingPoint, isNull);
      expect(e.meetingMapsUrl, isNull);
    });

    test('lê horário e ponto de encontro', () {
      final e = EventModel.fromMap(linha({
        'departure_at': '2026-09-20T16:30:00Z',
        'meeting_label': 'Posto Simon',
        'meeting_address': 'BR-101, Passo de Torres',
        'meeting_lat': -29.31,
        'meeting_lng': -49.72,
      }));
      expect(e.hasDeparture, isTrue);
      expect(e.departureAt!.toUtc().hour, 16);
      expect(e.meetingPoint!.label, 'Posto Simon');
      expect(e.meetingMapsUrl, contains('-29.31,-49.72'));
    });

    test('nome sem coordenada não vira ponto de encontro', () {
      // "Ver no mapa" precisa de lugar; só o nome não serve.
      final e = EventModel.fromMap(linha({'meeting_label': 'Posto Simon'}));
      expect(e.meetingPoint, isNull);
    });

    test('só o horário já conta como saída', () {
      final e = EventModel.fromMap(
          linha({'departure_at': '2026-09-20T16:30:00Z'}));
      expect(e.hasDeparture, isTrue);
    });

    test('copyWith leva a saída junto', () {
      final e = EventModel.fromMap(linha({
        'departure_at': '2026-09-20T16:30:00Z',
        'meeting_lat': -29.31,
        'meeting_lng': -49.72,
      }));
      final depois = e.copyWith(isInterested: true);
      expect(depois.departureAt, isNotNull);
      expect(depois.meetingPoint, isNotNull);
    });
  });

  group('EventDeparture.toDb', () {
    test('grava as cinco colunas', () {
      final m = EventDeparture(
        at: DateTime.utc(2026, 9, 20, 16, 30),
        meetingPoint: const LocationModel(
            lat: -29.31, lng: -49.72, label: 'Posto Simon', address: 'BR-101'),
      ).toDb();
      expect(m['meeting_label'], 'Posto Simon');
      expect(m['meeting_lat'], -29.31);
      expect(m['departure_at'], isNotNull);
    });

    test('vazia manda null explícito — é assim que a edição apaga', () {
      final m = const EventDeparture().toDb();
      expect(m.length, 5);
      expect(m.values.every((v) => v == null), isTrue);
    });
  });
}
