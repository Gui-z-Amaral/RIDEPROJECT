// Testes dos validadores puros dos fluxos de código (OTP) e senha.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/auth_validators.dart';

void main() {
  group('isValidOtpCode', () {
    test('aceita exatamente 6 dígitos', () {
      expect(isValidOtpCode('123456'), isTrue);
      expect(isValidOtpCode('000000'), isTrue);
    });

    test('tolera espaços nas pontas (colar do email)', () {
      expect(isValidOtpCode(' 123456 '), isTrue);
    });

    test('rejeita tamanhos errados, letras e vazio', () {
      expect(isValidOtpCode('12345'), isFalse);
      expect(isValidOtpCode('1234567'), isFalse);
      expect(isValidOtpCode('12a456'), isFalse);
      expect(isValidOtpCode(''), isFalse);
      expect(isValidOtpCode('12 34 56'), isFalse);
    });
  });

  group('passwordError', () {
    test('senha curta retorna erro', () {
      expect(passwordError('12345'), 'Mínimo 6 caracteres');
    });

    test('senha ok sem confirmação retorna null', () {
      expect(passwordError('123456'), isNull);
    });

    test('confirmação diferente retorna erro', () {
      expect(passwordError('123456', confirm: '654321'),
          'As senhas não conferem');
    });

    test('confirmação igual retorna null', () {
      expect(passwordError('senha123', confirm: 'senha123'), isNull);
    });
  });

  group('looksLikeEmail', () {
    test('emails comuns passam', () {
      expect(looksLikeEmail('a@b.com'), isTrue);
      expect(looksLikeEmail('nome.sobrenome@dominio.com.br'), isTrue);
      expect(looksLikeEmail(' espacos@dominio.com '), isTrue);
    });

    test('formatos inválidos falham', () {
      expect(looksLikeEmail('sem-arroba.com'), isFalse);
      expect(looksLikeEmail('a@semdominio'), isFalse);
      expect(looksLikeEmail('a b@c.com'), isFalse);
      expect(looksLikeEmail(''), isFalse);
    });
  });
}
