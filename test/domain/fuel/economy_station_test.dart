import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';

FuelEntry fill({
  required int km,
  required double liters,
  bool full = true,
  String? station,
  bool missed = false,
}) {
  return FuelEntry(
    id: 'f$km',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 1, 1).add(Duration(days: km ~/ 100)),
    odometerKm: km,
    volumeL: liters,
    pricePerL: 1.5,
    total: liters * 1.5,
    fullTank: full,
    missedFill: missed,
    station: station,
    createdBy: 'u1',
  );
}

void main() {
  // A span's fuel is what went in *after* the opening full tank, up to and
  // including the closing one — so the closing fill's station is what bought
  // the fuel that was burned. That is only unambiguous when no partial fill
  // from somewhere else contributed to the same span.
  group('which station supplied the fuel a span measured', () {
    test('a span closed at a station is attributed to it', () {
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'INA'),
        fill(km: 1500, liters: 30, station: 'Petrol'),
      ]);

      expect(points, hasLength(1));
      expect(
        points.single.station,
        'Petrol',
        reason: 'the fuel burned over the span is the fuel bought to close it',
      );
    });

    test('a partial fill from the same station keeps the attribution', () {
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'INA'),
        fill(km: 1200, liters: 10, full: false, station: 'INA'),
        fill(km: 1500, liters: 25, station: 'INA'),
      ]);

      expect(points.single.station, 'INA');
    });

    test('a partial fill from elsewhere makes the span unattributable', () {
      // Two stations' fuel burned together measures neither of them.
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'INA'),
        fill(km: 1200, liters: 10, full: false, station: 'Shell'),
        fill(km: 1500, liters: 25, station: 'INA'),
      ]);

      expect(points.single.station, isNull);
    });

    test('a fill with no station named leaves the span unattributed', () {
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'INA'),
        fill(km: 1500, liters: 30),
      ]);

      expect(points.single.station, isNull);
    });

    test('the opening tank does not decide the attribution', () {
      // Its fuel was burned before the span started.
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'Shell'),
        fill(km: 1500, liters: 30, station: 'INA'),
        fill(km: 2000, liters: 30, station: 'INA'),
      ]);

      expect(points.map((p) => p.station), ['INA', 'INA']);
    });

    test('whitespace is not a station', () {
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'INA'),
        fill(km: 1500, liters: 30, station: '   '),
      ]);

      expect(points.single.station, isNull);
    });

    test('a broken span produces no point at all, station or not', () {
      final points = FuelEconomy.compute([
        fill(km: 1000, liters: 40, station: 'INA'),
        fill(km: 1500, liters: 30, station: 'INA', missed: true),
      ]);

      expect(points, isEmpty);
    });
  });
}
