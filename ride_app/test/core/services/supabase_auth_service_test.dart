// Testes do parser extractMissingColumn.
//
// Esse método é o que torna o updateProfile resiliente a colunas
// ainda não criadas no banco (ex: migração pendente). Se o parser
// começa a retornar null incorretamente, o update falha inteiro
// em vez de só dropar a coluna que falta.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Helper para construir PostgrestException no formato retornado pelo
// PostgREST quando uma coluna não existe no schema cache.
PostgrestException _pgrst204(String columnName) {
  return PostgrestException(
    message:
        "Could not find the '$columnName' column of 'profiles' in the schema cache",
    code: 'PGRST204',
    details: 'Bad Request',
  );
}

void main() {
  group('extractMissingColumn', () {
    test('extrai o nome da coluna de uma PGRST204 típica', () {
      final e = _pgrst204('city');
      expect(SupabaseAuthService.extractMissingColumn(e), 'city');
    });

    test('funciona com colunas que tem underline no nome', () {
      final e = _pgrst204('trip_style');
      expect(SupabaseAuthService.extractMissingColumn(e), 'trip_style');
    });

    test('retorna null se o código não for PGRST204', () {
      final e = PostgrestException(
        message: "Could not find the 'x' column of 'y'",
        code: '42501', // insufficient privilege, não é nosso caso
        details: 'Permission denied',
      );
      expect(SupabaseAuthService.extractMissingColumn(e), isNull);
    });

    test('retorna null se a mensagem não casar com o formato esperado', () {
      final e = PostgrestException(
        message: 'Something totally different',
        code: 'PGRST204',
        details: 'Bad Request',
      );
      expect(SupabaseAuthService.extractMissingColumn(e), isNull);
    });

    test('pega apenas a PRIMEIRA coluna quando a mensagem menciona várias',
        () {
      // Defensive: se um dia o PostgREST mudar o texto, ainda pegamos
      // uma coluna válida em vez de null.
      final e = PostgrestException(
        message:
            "Could not find the 'city' column of 'profiles' (or 'photos' column)",
        code: 'PGRST204',
        details: 'Bad Request',
      );
      expect(SupabaseAuthService.extractMissingColumn(e), 'city');
    });
  });
}
