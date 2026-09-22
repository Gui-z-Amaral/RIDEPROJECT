import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:ride_app/features/clubs/viewmodels/club_viewmodel.dart';

void main() {
  group('ClubViewModel.mensagemDeErro', () {
    test('permissão negada pelo RLS vira explicação, não "tente de novo"', () {
      final msg = ClubViewModel.mensagemDeErro(
        PostgrestException(message: 'new row violates row-level security',
            code: '42501'),
      );
      expect(msg, 'Você não tem permissão para alterar este motoclube.');
    });

    test('outro erro do banco carrega o código para dar diagnóstico', () {
      final msg = ClubViewModel.mensagemDeErro(
        PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(msg, contains('23505'));
    });

    test('nunca repassa a mensagem crua do banco', () {
      // Ela descreve tabela e coluna — não vai para a tela.
      final msg = ClubViewModel.mensagemDeErro(
        PostgrestException(
            message: 'column clubs.segredo does not exist', code: '42703'),
      );
      expect(msg, isNot(contains('clubs')));
      expect(msg, isNot(contains('segredo')));
    });

    test('erro sem código não escreve "(código null)"', () {
      final msg =
          ClubViewModel.mensagemDeErro(PostgrestException(message: 'x'));
      expect(msg, isNot(contains('código')));
      expect(msg, isNotEmpty);
    });

    test('falha de rede fala de conexão', () {
      final msg = ClubViewModel.mensagemDeErro(Exception('socket closed'));
      expect(msg, contains('conexão'));
    });
  });
}
