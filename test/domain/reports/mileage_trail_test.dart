import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/odometer_history.dart';
import 'package:garage/domain/reports/mileage_trail.dart';

OdometerSample at(int year, int month, int km) =>
    OdometerSample(date: DateTime.utc(year, month, 1), km: km);

void main() {
  test('a year is what the reading rose by inside it', () {
    final trail = mileageTrail([
      at(2024, 1, 100000),
      at(2024, 12, 118000),
      at(2025, 6, 129000),
    ]);

    expect(trail.map((year) => year.year), [2024, 2025]);
    expect(trail.first.km, 18000);
    expect(trail.first.endKm, 118000);
    expect(trail.first.records, 2);
  });

  test('the first year counts only from its first reading', () {
    // A car whose records start in June cannot say what it did in May, and
    // printing a full year's distance for half a year of records would be an
    // invented figure on a document a buyer is reading.
    final trail = mileageTrail([at(2024, 6, 100000), at(2024, 12, 106000)]);

    expect(trail.single.km, 6000);
    expect(trail.single.partial, isTrue);
  });

  test('a later year continues from where the one before ended', () {
    // Without this, January's reading would be the year's start and the
    // distance driven over the New Year would vanish from the report.
    final trail = mileageTrail([
      at(2024, 12, 100000),
      at(2025, 1, 101000),
      at(2025, 12, 115000),
    ]);

    expect(trail.last.year, 2025);
    expect(trail.last.km, 15000);
    expect(trail.last.partial, isFalse);
  });

  test('a year with one reading and none before it claims no distance', () {
    final trail = mileageTrail([at(2024, 6, 100000)]);

    expect(trail.single.km, isNull);
    expect(trail.single.endKm, 100000);
  });

  test('a gap year is not invented', () {
    // Nothing was recorded in 2025. The trail says so by leaving it out
    // rather than by drawing a zero, which would read as a car that sat still.
    final trail = mileageTrail([
      at(2024, 6, 100000),
      at(2024, 12, 110000),
      at(2026, 3, 140000),
    ]);

    expect(trail.map((year) => year.year), [2024, 2026]);
    expect(
      trail.last.km,
      30000,
      reason: 'measured from the last known reading',
    );
    expect(trail.last.sinceLastReading, isTrue);
  });

  test('no readings, no trail', () {
    expect(mileageTrail(const []), isEmpty);
  });
}
