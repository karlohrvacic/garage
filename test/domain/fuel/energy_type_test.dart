import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/energy_type.dart';

void main() {
  group('what a vehicle runs on', () {
    test('petrol, diesel, and LPG are all liquid fuel', () {
      for (final key in ['fuel_petrol', 'fuel_diesel', 'fuel_lpg']) {
        expect(EnergyType.forFuelKey(key), EnergyType.liquid, reason: key);
      }
    });

    test('electric is measured in energy, not volume', () {
      expect(EnergyType.forFuelKey('fuel_electric'), EnergyType.electric);
    });

    test('a hybrid still fills a tank, so it counts as liquid', () {
      // A plug-in hybrid logs both, but the tank is what the economy figure
      // is built from; treating it as electric would mislabel every fill.
      expect(EnergyType.forFuelKey('fuel_hybrid'), EnergyType.liquid);
    });

    test('an unknown key falls back to liquid rather than throwing', () {
      expect(EnergyType.forFuelKey('fuel_hydrogen'), EnergyType.liquid);
    });
  });

  group('how much went in', () {
    test('liquid is stored and shown as a volume', () {
      expect(EnergyType.liquid.isElectric, isFalse);
    });

    test('electric is stored in the same column, read as kWh', () {
      expect(EnergyType.electric.isElectric, isTrue);
    });
  });
}
