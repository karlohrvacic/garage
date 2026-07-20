import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';

int _seq = 0;

FuelEntry fill({
  required int odometerKm,
  required double volumeL,
  bool fullTank = true,
  bool missedFill = false,
  double? total,
}) {
  _seq++;
  return FuelEntry(
    id: 'e$_seq',
    vehicleId: 'v1',
    date: DateTime(2026, 1, 1).add(Duration(days: _seq)),
    odometerKm: odometerKm,
    volumeL: volumeL,
    total: total,
    fullTank: fullTank,
    missedFill: missedFill,
    createdBy: 'u1',
  );
}

void main() {
  setUp(() => _seq = 0);

  test('the first full tank yields no point because it has no baseline', () {
    final points = FuelEconomy.compute([fill(odometerKm: 1000, volumeL: 40)]);

    expect(points, isEmpty);
  });

  test('two consecutive full tanks yield one point', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1000, volumeL: 40),
      fill(odometerKm: 1500, volumeL: 35),
    ]);

    expect(points, hasLength(1));
    // 35 l over 500 km == 7.0 l/100km
    expect(points.single.litersPer100Km, closeTo(7.0, 0.0001));
    expect(points.single.distanceKm, 500);
    expect(points.single.entryId, 'e2');
  });

  test('a partial fill folds its volume into the next full tank', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1000, volumeL: 40),
      fill(odometerKm: 1200, volumeL: 15, fullTank: false),
      fill(odometerKm: 1500, volumeL: 20),
    ]);

    expect(points, hasLength(1));
    // (15 + 20) l over 500 km == 7.0 l/100km
    expect(points.single.litersPer100Km, closeTo(7.0, 0.0001));
    expect(points.single.volumeL, closeTo(35, 0.0001));
  });

  test('a missed fill breaks the chain instead of reporting a wrong figure', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1000, volumeL: 40),
      fill(odometerKm: 1500, volumeL: 35, missedFill: true),
      fill(odometerKm: 2000, volumeL: 30),
    ]);

    // The span ending at the missed fill is unknowable, but the span after it
    // is fine: 30 l over 500 km == 6.0 l/100km.
    expect(points, hasLength(1));
    expect(points.single.entryId, 'e3');
    expect(points.single.litersPer100Km, closeTo(6.0, 0.0001));
  });

  test('entries are sorted by odometer before computing', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1500, volumeL: 35),
      fill(odometerKm: 1000, volumeL: 40),
    ]);

    expect(points, hasLength(1));
    expect(points.single.distanceKm, 500);
  });

  test('a zero-distance span is skipped rather than dividing by zero', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1000, volumeL: 40),
      fill(odometerKm: 1000, volumeL: 35),
    ]);

    expect(points, isEmpty);
  });

  test('same-odometer fills give the same result regardless of input order',
      () {
    // A full and a partial fill share odometer 1000 — a degenerate
    // zero-distance pair. Sorting on odometer alone left their relative order
    // dependent on the caller's list order, which decides whether the partial
    // folds into the span closed by the full tank at 1500. The (odometer,
    // date, fullTank) tie-break makes the order total, so both arrangements
    // fold the partial in and yield 10.0 l/100km.
    final full1 = fill(odometerKm: 1000, volumeL: 40);
    final partial = fill(odometerKm: 1000, volumeL: 20, fullTank: false);
    final full2 = fill(odometerKm: 1500, volumeL: 30);

    final oneOrder = FuelEconomy.compute([full1, partial, full2]);
    final otherOrder = FuelEconomy.compute([partial, full2, full1]);

    expect(
      oneOrder.map((p) => p.litersPer100Km),
      otherOrder.map((p) => p.litersPer100Km),
    );
    expect(
      oneOrder.map((p) => p.entryId),
      otherOrder.map((p) => p.entryId),
    );
    // Pin the resolved order: the partial folds in, so 50 l over 500 km.
    expect(oneOrder.single.litersPer100Km, closeTo(10.0, 0.0001));
  });

  test('cost per km is computed when the fills carry totals', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1000, volumeL: 40, total: 60),
      fill(odometerKm: 1500, volumeL: 35, total: 52.5),
    ]);

    // 52.50 over 500 km == 0.105 per km
    expect(points.single.costPerKm, closeTo(0.105, 0.0001));
  });

  test('cost per km is null when any fill in the span lacks a total', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 1000, volumeL: 40, total: 60),
      fill(odometerKm: 1200, volumeL: 15, fullTank: false),
      fill(odometerKm: 1500, volumeL: 20, total: 30),
    ]);

    expect(points.single.costPerKm, isNull);
  });

  test('average weights each point by the distance it covers', () {
    final points = FuelEconomy.compute([
      fill(odometerKm: 0, volumeL: 40),
      fill(odometerKm: 100, volumeL: 10), // 10 l/100km over 100 km
      fill(odometerKm: 1100, volumeL: 50), // 5 l/100km over 1000 km
    ]);

    expect(points, hasLength(2));
    // Weighted: (10 + 50) l over 1100 km == 5.45 l/100km, not the naive 7.5.
    expect(FuelEconomy.average(points), closeTo(5.4545, 0.001));
  });

  test('the average of no points is null', () {
    expect(FuelEconomy.average([]), isNull);
  });
}
