import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/features/trips/viewmodels/trip_viewmodel.dart';

void main() {
  group('TripViewModel — visibilidade ao criar', () {
    test('viagem pessoal nasce pública', () {
      final vm = TripViewModel()..resetForm();
      vm.setClubId(null);
      expect(vm.isPublic, isTrue);
    });

    test('viagem criada dentro do motoclube nasce privada', () {
      // Nascer pública publicava a viagem fora do clube sem a pessoa
      // perceber — foi o que fez um evento de clube aparecer na aba geral.
      final vm = TripViewModel()..resetForm();
      vm.setClubId('clube-1');
      expect(vm.isPublic, isFalse);
    });

    test('quem cria ainda pode escolher tornar pública', () {
      final vm = TripViewModel()..resetForm();
      vm.setClubId('clube-1');
      vm.setIsPublic(true);
      expect(vm.isPublic, isTrue);
    });
  });
}
