import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/energy_type.dart';
import 'package:garage/domain/fuel/implied_consumption.dart';

void main() {
  group('what a fill-up implies about consumption', () {
    test('is nothing without both a distance and a quantity', () {
      expect(
        impliedConsumption(
          distanceKm: null,
          quantity: 40,
          energy: EnergyType.liquid,
        ),
        isNull,
      );
      expect(
        impliedConsumption(
          distanceKm: 500,
          quantity: null,
          energy: EnergyType.liquid,
        ),
        isNull,
      );
    });

    test('is litres per hundred kilometres for a liquid fuel', () {
      expect(
        impliedConsumption(
          distanceKm: 500,
          quantity: 40,
          energy: EnergyType.liquid,
        ),
        closeTo(8, 0.001),
      );
    });

    test('a car that has not moved implies nothing, not infinity', () {
      // A second fill on the same forecourt: topping up after a partial fill
      // is ordinary, and reporting it as an impossible figure would train
      // people to ignore the warning.
      expect(
        impliedConsumption(
          distanceKm: 0,
          quantity: 40,
          energy: EnergyType.liquid,
        ),
        isNull,
      );
    });
  });

  group('whether that figure is believable', () {
    test('an ordinary car is not flagged', () {
      expect(isImplausibleConsumption(8, EnergyType.liquid), isFalse);
      expect(isImplausibleConsumption(3.1, EnergyType.liquid), isFalse);
      expect(isImplausibleConsumption(24, EnergyType.liquid), isFalse);
    });

    test('a mistyped odometer shows up as an impossible thirst', () {
      // 40 litres over 20 km — the classic transposed digit — is 200 l/100 km.
      expect(isImplausibleConsumption(200, EnergyType.liquid), isTrue);
    });

    test('a fill that is too small for the distance shows up too', () {
      // Five litres over a thousand kilometres is not a car, it is a missed
      // fill-up nobody marked.
      expect(isImplausibleConsumption(0.5, EnergyType.liquid), isTrue);
    });

    test('an electric vehicle is measured against its own range', () {
      // kWh per hundred kilometres: 15 is ordinary, 200 is a typo.
      expect(isImplausibleConsumption(15, EnergyType.electric), isFalse);
      expect(isImplausibleConsumption(200, EnergyType.electric), isTrue);
      expect(isImplausibleConsumption(1, EnergyType.electric), isTrue);
    });
  });
}
