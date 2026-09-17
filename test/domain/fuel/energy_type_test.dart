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

  // A plug-in hybrid kept as petrol still charges in kilowatt-hours. Deciding
  // by the car alone read every one of its charges as litres.
  group('what one fill-up is measured in', () {
    test('a fill-up that names its fuel is measured in that fuel', () {
      expect(
        EnergyType.forEntry('fuel_electric', vehicle: EnergyType.liquid),
        EnergyType.electric,
      );
      expect(
        EnergyType.forEntry('fuel_petrol', vehicle: EnergyType.electric),
        EnergyType.liquid,
      );
    });

    test('one that names none is measured in what the car mainly takes', () {
      expect(
        EnergyType.forEntry(null, vehicle: EnergyType.electric),
        EnergyType.electric,
      );
      expect(
        EnergyType.forEntry(null, vehicle: EnergyType.liquid),
        EnergyType.liquid,
      );
    });
  });

  // Litres and kilowatt-hours do not add up, so a total or an average is taken
  // over fill-ups of one kind and has to say which.
  group('what a figure over many fill-ups is measured in', () {
    test('liquid when any of them is', () {
      expect(
        EnergyType.measuredOver([EnergyType.electric, EnergyType.liquid]),
        EnergyType.liquid,
      );
    });

    test('electric when every one of them is', () {
      expect(
        EnergyType.measuredOver([EnergyType.electric, EnergyType.electric]),
        EnergyType.electric,
      );
    });

    test('liquid when there is nothing to measure', () {
      expect(EnergyType.measuredOver(const []), EnergyType.liquid);
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
