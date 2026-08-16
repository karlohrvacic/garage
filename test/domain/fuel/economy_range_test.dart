import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';

EconomyPoint point(double litersPer100Km) {
  return EconomyPoint(
    entryId: 'e$litersPer100Km',
    date: DateTime.utc(2026, 1, 1),
    odometerKm: 1000,
    litersPer100Km: litersPer100Km,
    distanceKm: 500,
    volumeL: 30,
  );
}

void main() {
  group('a vehicle economy range', () {
    // The gauge used a fixed 4 to 12 l/100km scale, so 5.9 read as "76%" of
    // nothing in particular. A thirsty car sat at zero forever and an electric
    // one, measured in kWh, was meaningless. A car's own history is the only
    // scale that is true for every vehicle.
    test('runs from the best tank recorded to the worst', () {
      final range = EconomyRange.of([point(6.4), point(5.2), point(7.1)]);

      expect(range!.best, 5.2);
      expect(range.worst, 7.1);
    });

    test('places the best tank at the full end', () {
      final range = EconomyRange.of([point(5.2), point(7.1)]);

      expect(range!.fractionFor(5.2), 1);
    });

    test('places the worst tank at the empty end', () {
      final range = EconomyRange.of([point(5.2), point(7.1)]);

      expect(range!.fractionFor(7.1), 0);
    });

    test('places a middling tank in the middle', () {
      final range = EconomyRange.of([point(5.0), point(7.0)]);

      expect(range!.fractionFor(6.0), closeTo(0.5, 0.001));
    });

    test('is null with too little history to compare against', () {
      expect(EconomyRange.of([point(5.9)]), isNull);
      expect(EconomyRange.of(const []), isNull);
    });

    test('is null when every tank was identical, which scales nothing', () {
      expect(EconomyRange.of([point(5.9), point(5.9)]), isNull);
    });

    // Exact equality is the wrong test for arithmetic done in floating point.
    // Twelve spans that all worked out to 6.0 l/100km came back differing by
    // 9e-16, which was enough to be treated as a real range: the ring then
    // scaled a rounding error and read full, under a caption that said
    // "Best 6.0 · Worst 6.0".
    test('is null when the spread is too small to have been measured', () {
      expect(EconomyRange.of([point(6.0), point(6.0 + 1e-15)]), isNull);
      expect(EconomyRange.of([point(6.0), point(6.04)]), isNull);
    });

    test('a spread the screen can actually print is a range', () {
      expect(EconomyRange.of([point(6.0), point(6.2)]), isNotNull);
    });

    test('clamps a figure outside the recorded range', () {
      final range = EconomyRange.of([point(5.0), point(7.0)]);

      expect(range!.fractionFor(4.0), 1);
      expect(range.fractionFor(9.0), 0);
    });
  });
}
