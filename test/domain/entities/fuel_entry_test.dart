import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';

FuelEntry entry({double volumeL = 40, double? pricePerL, double? total}) {
  return FuelEntry(
    id: 'e1',
    vehicleId: 'v1',
    date: DateTime(2026, 1, 1),
    odometerKm: 1000,
    volumeL: volumeL,
    pricePerL: pricePerL,
    total: total,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

void main() {
  group('deriveThird', () {
    test('computes the total from volume and unit price', () {
      expect(
        FuelEntry.deriveThird(volumeL: 40, pricePerL: 1.5, total: null),
        closeTo(60, 0.0001),
      );
    });

    test('computes the unit price from volume and total', () {
      expect(
        FuelEntry.deriveThird(volumeL: 40, pricePerL: null, total: 60),
        closeTo(1.5, 0.0001),
      );
    });

    test('computes the volume from unit price and total', () {
      expect(
        FuelEntry.deriveThird(volumeL: null, pricePerL: 1.5, total: 60),
        closeTo(40, 0.0001),
      );
    });

    test('returns null when fewer than two values are known', () {
      expect(
        FuelEntry.deriveThird(volumeL: 40, pricePerL: null, total: null),
        isNull,
      );
    });

    test('returns null rather than dividing by zero', () {
      expect(
        FuelEntry.deriveThird(volumeL: 0, pricePerL: null, total: 60),
        isNull,
      );
    });

    test('returns null when all three are already known', () {
      expect(
        FuelEntry.deriveThird(volumeL: 40, pricePerL: 1.5, total: 60),
        isNull,
      );
    });
  });

  test('entries with the same field values are equal', () {
    expect(entry(), entry());
    expect(entry().hashCode, entry().hashCode);
  });

  test('copyWith replaces only the named field', () {
    final updated = entry().copyWith(odometerKm: 2000);

    expect(updated.odometerKm, 2000);
    expect(updated.volumeL, entry().volumeL);
  });
}
