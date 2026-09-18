import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/constants/app_links.dart';
import 'package:ride_app/core/models/club_invite.dart';

void main() {
  group('AppLinks.clubInvite', () {
    test('monta o link do convite no domínio do PWA', () {
      expect(AppLinks.clubInvite('abc123'),
          'https://app.ride.dev.br/ci/abc123');
    });
  });

  group('ClubInviteKind', () {
    test('cada tipo tem o código que o banco espera', () {
      expect(ClubInviteKind.permanent.code, 'permanent');
      expect(ClubInviteKind.single.code, 'single');
      expect(ClubInviteKind.temporary.code, 'temporary');
    });

    test('ida e volta entre tipo e código', () {
      for (final k in ClubInviteKind.values) {
        expect(ClubInviteKindX.fromCode(k.code), k);
      }
    });

    test('código desconhecido não estoura', () {
      expect(ClubInviteKindX.fromCode('outro'), isNull);
      expect(ClubInviteKindX.fromCode(null), isNull);
    });

    test('todos têm rótulo e explicação preenchidos', () {
      for (final k in ClubInviteKind.values) {
        expect(k.label, isNotEmpty);
        expect(k.hint, isNotEmpty);
      }
    });
  });

  group('clubInviteStatusFrom', () {
    test('lê os estados que o servidor devolve', () {
      expect(clubInviteStatusFrom('valido'), ClubInviteStatus.valido);
      expect(clubInviteStatusFrom('expirado'), ClubInviteStatus.expirado);
      expect(clubInviteStatusFrom('usado'), ClubInviteStatus.usado);
      expect(clubInviteStatusFrom('revogado'), ClubInviteStatus.revogado);
    });

    test('qualquer outra coisa vira inválido', () {
      // Estado desconhecido nunca pode virar "válido" por omissão: quem decide
      // se o convite vale é o servidor.
      expect(clubInviteStatusFrom(null), ClubInviteStatus.invalido);
      expect(clubInviteStatusFrom(''), ClubInviteStatus.invalido);
      expect(clubInviteStatusFrom('qualquer'), ClubInviteStatus.invalido);
    });
  });

  group('ClubInvitePreview', () {
    test('lê a resposta do servidor', () {
      final p = ClubInvitePreview.fromMap({
        'club_id': 'c1',
        'name': 'MotoAru',
        'city': 'Araranguá',
        'state_uf': 'SC',
        'members': 23,
        'status': 'valido',
      });
      expect(p.isValid, isTrue);
      expect(p.name, 'MotoAru');
      expect(p.members, 23);
      expect(p.place, 'Araranguá - SC');
    });

    test('convite inválido não é tratado como válido', () {
      final p = ClubInvitePreview.fromMap({'status': 'expirado'});
      expect(p.isValid, isFalse);
      expect(p.status, ClubInviteStatus.expirado);
    });

    test('sem clube não é válido, mesmo dizendo válido', () {
      // Defesa contra resposta malformada: sem id não há para onde entrar.
      final p = ClubInvitePreview.fromMap({'status': 'valido'});
      expect(p.isValid, isFalse);
    });

    test('lugar vazio quando não há cidade nem UF', () {
      expect(ClubInvitePreview.fromMap({'status': 'valido'}).place, '');
    });
  });

  group('ClubInvite.isSpent', () {
    test('convite usado está gasto', () {
      final i = ClubInvite.fromMap({
        'token': 't',
        'kind': 'single',
        'used_at': '2026-09-17T10:00:00Z',
      });
      expect(i.isSpent, isTrue);
    });

    test('convite expirado está gasto', () {
      final i = ClubInvite.fromMap({
        'token': 't',
        'kind': 'temporary',
        'expires_at': '2020-01-01T00:00:00Z',
      });
      expect(i.isSpent, isTrue);
    });

    test('permanente sem uso não está gasto', () {
      final i = ClubInvite.fromMap({'token': 't', 'kind': 'permanent'});
      expect(i.isSpent, isFalse);
      expect(i.kind, ClubInviteKind.permanent);
    });
  });
}
