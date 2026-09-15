import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/wake_lock_service.dart';

/// Estes testes rodam na VM (kIsWeb == false), ou seja, no caminho "nativo".
/// O contrato aqui é justamente que no nativo o serviço **não faz nada** — o
/// app já grava em segundo plano e não queremos mudar o comportamento da tela.
void main() {
  group('WakeLockService — plataforma nativa (kIsWeb == false)', () {
    test('isSupported acompanha kIsWeb', () {
      expect(WakeLockService.isSupported, kIsWeb);
      expect(WakeLockService.isSupported, isFalse); // teste roda na VM
    });

    test('começa inativo', () {
      expect(WakeLockService.isActive, isFalse);
    });

    test('enable() é no-op no nativo (não marca como ativo)', () async {
      await WakeLockService.enable();
      expect(WakeLockService.isActive, isFalse);
    });

    test('disable() é seguro mesmo sem nunca ter ligado', () async {
      await WakeLockService.disable();
      expect(WakeLockService.isActive, isFalse);
    });

    test('enable/disable repetidos não quebram', () async {
      await WakeLockService.enable();
      await WakeLockService.enable();
      await WakeLockService.disable();
      await WakeLockService.disable();
      expect(WakeLockService.isActive, isFalse);
    });
  });
}
