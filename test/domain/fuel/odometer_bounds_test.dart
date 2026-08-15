import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/odometer_bounds.dart';

FuelEntry fill({
  required String id,
  required int odometerKm,
  required DateTime date,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    odometerKm: odometerKm,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

final _log = [
  fill(id: 'f1', odometerKm: 50000, date: DateTime.utc(2026, 5, 1)),
  fill(id: 'f2', odometerKm: 50800, date: DateTime.utc(2026, 6, 1)),
  fill(id: 'f3', odometerKm: 51600, date: DateTime.utc(2026, 7, 1)),
];

void main() {
  group('a new fill-up', () {
    test('is bounded below by the newest reading', () {
      final bounds = OdometerBounds.forDate(
        _log,
        date: DateTime.utc(2026, 8, 1),
      );

      expect(bounds.previousKm, 51600);
      expect(bounds.nextKm, isNull);
      expect(bounds.isTooLow(51000), isTrue);
      expect(bounds.isTooLow(52000), isFalse);
    });

    test('backdated between two fills is bounded by both of them', () {
      final bounds = OdometerBounds.forDate(
        _log,
        date: DateTime.utc(2026, 6, 15),
      );

      expect(bounds.previousKm, 50800);
      expect(bounds.nextKm, 51600);
      expect(bounds.isTooLow(50700), isTrue);
      expect(bounds.isTooHigh(51700), isTrue);
      expect(bounds.isTooLow(51000), isFalse);
      expect(bounds.isTooHigh(51000), isFalse);
    });

    test('has no bounds at all when the log is empty', () {
      final bounds = OdometerBounds.forDate(
        const [],
        date: DateTime.utc(2026, 6, 15),
      );

      expect(bounds.previousKm, isNull);
      expect(bounds.nextKm, isNull);
      expect(bounds.isTooLow(0), isFalse);
      expect(bounds.isTooHigh(999999), isFalse);
    });
  });

  group('an edited fill-up', () {
    test('is never measured against its own stored reading', () {
      final bounds = OdometerBounds.forDate(
        _log,
        date: DateTime.utc(2026, 6, 1),
        excludingId: 'f2',
      );

      expect(bounds.previousKm, 50000);
      expect(bounds.nextKm, 51600);
      expect(bounds.isTooLow(50800), isFalse);
    });

    test('the oldest entry keeps its reading unflagged', () {
      final bounds = OdometerBounds.forDate(
        _log,
        date: DateTime.utc(2026, 5, 1),
        excludingId: 'f1',
      );

      expect(bounds.previousKm, isNull);
      expect(bounds.nextKm, 50800);
      expect(bounds.isTooLow(50000), isFalse);
      expect(bounds.isTooHigh(50000), isFalse);
    });

    test('moved past its neighbour, it is flagged again', () {
      final bounds = OdometerBounds.forDate(
        _log,
        date: DateTime.utc(2026, 6, 1),
        excludingId: 'f2',
      );

      expect(bounds.isTooLow(49000), isTrue);
      expect(bounds.isTooHigh(52000), isTrue);
    });
  });

  test('same-day fills impose no order on each other', () {
    final sameDay = [
      fill(id: 'f1', odometerKm: 50000, date: DateTime.utc(2026, 5, 1)),
      fill(id: 'f2', odometerKm: 50040, date: DateTime.utc(2026, 5, 1)),
    ];

    final bounds = OdometerBounds.forDate(
      sameDay,
      date: DateTime.utc(2026, 5, 1),
      excludingId: 'f2',
    );

    expect(bounds.previousKm, isNull);
    expect(bounds.nextKm, isNull);
  });

  test('a local date is compared by its calendar day', () {
    final bounds = OdometerBounds.forDate(
      _log,
      date: DateTime(2026, 6, 15, 23, 30),
    );

    expect(bounds.previousKm, 50800);
    expect(bounds.nextKm, 51600);
  });
}
