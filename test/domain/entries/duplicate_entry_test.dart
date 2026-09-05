import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entries/duplicate_entry.dart';

CostEntry cost({
  String id = 'c1',
  String category = 'insurance',
  double amount = 210,
  DateTime? date,
}) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 4, 2),
    category: category,
    amount: amount,
    createdBy: 'u1',
  );
}

ServiceEntry service({
  String id = 's1',
  int odometerKm = 120000,
  List<String> keys = const ['service_oil_change'],
  DateTime? date,
}) {
  return ServiceEntry(
    id: id,
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 4, 2),
    odometerKm: odometerKm,
    serviceTypeKeys: keys,
    createdBy: 'u1',
  );
}

void main() {
  group('a cost that repeats one already logged', () {
    test('same day, same category, same amount is a duplicate', () {
      expect(
        duplicatesExistingCost(
          existing: [cost()],
          date: DateTime.utc(2026, 4, 2),
          category: 'insurance',
          amount: 210,
        ),
        isTrue,
      );
    });

    test('the time of day does not matter, only the day', () {
      expect(
        duplicatesExistingCost(
          existing: [cost(date: DateTime.utc(2026, 4, 2, 8))],
          date: DateTime.utc(2026, 4, 2, 19, 30),
          category: 'insurance',
          amount: 210,
        ),
        isTrue,
      );
    });

    test('a cent apart is still the same payment', () {
      expect(
        duplicatesExistingCost(
          existing: [cost(amount: 210.004)],
          date: DateTime.utc(2026, 4, 2),
          category: 'insurance',
          amount: 210,
        ),
        isTrue,
      );
    });

    test('a different amount is a different payment', () {
      expect(
        duplicatesExistingCost(
          existing: [cost(amount: 210)],
          date: DateTime.utc(2026, 4, 2),
          category: 'insurance',
          amount: 211,
        ),
        isFalse,
      );
    });

    test('a different category on the same day is not a duplicate', () {
      expect(
        duplicatesExistingCost(
          existing: [cost(category: 'insurance')],
          date: DateTime.utc(2026, 4, 2),
          category: 'parking',
          amount: 210,
        ),
        isFalse,
      );
    });

    test('another day is another payment', () {
      expect(
        duplicatesExistingCost(
          existing: [cost(date: DateTime.utc(2026, 4, 1))],
          date: DateTime.utc(2026, 4, 2),
          category: 'insurance',
          amount: 210,
        ),
        isFalse,
      );
    });

    test('the entry being edited never duplicates itself', () {
      expect(
        duplicatesExistingCost(
          existing: [cost(id: 'c1')],
          editingId: 'c1',
          date: DateTime.utc(2026, 4, 2),
          category: 'insurance',
          amount: 210,
        ),
        isFalse,
      );
    });
  });

  group('a service that repeats one already logged', () {
    test('same day, same odometer, same job is a duplicate', () {
      expect(
        duplicatesExistingService(
          existing: [service()],
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 120000,
          serviceTypeKeys: const ['service_oil_change'],
        ),
        isTrue,
      );
    });

    test('one shared job out of several is enough', () {
      expect(
        duplicatesExistingService(
          existing: [
            service(keys: const ['service_oil_change', 'service_air_filter']),
          ],
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 120000,
          serviceTypeKeys: const ['service_air_filter'],
        ),
        isTrue,
      );
    });

    test('a different job on the same visit is not a duplicate', () {
      // Two entries for one visit is how some people log a day's work, and
      // warning about it would be wrong.
      expect(
        duplicatesExistingService(
          existing: [
            service(keys: const ['service_oil_change']),
          ],
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 120000,
          serviceTypeKeys: const ['service_brake_fluid'],
        ),
        isFalse,
      );
    });

    test('the same job at another odometer is another service', () {
      expect(
        duplicatesExistingService(
          existing: [service(odometerKm: 120000)],
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 120400,
          serviceTypeKeys: const ['service_oil_change'],
        ),
        isFalse,
      );
    });

    test('the entry being edited never duplicates itself', () {
      expect(
        duplicatesExistingService(
          existing: [service(id: 's1')],
          editingId: 's1',
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 120000,
          serviceTypeKeys: const ['service_oil_change'],
        ),
        isFalse,
      );
    });

    test('nothing selected yet is nothing to duplicate', () {
      expect(
        duplicatesExistingService(
          existing: [service()],
          date: DateTime.utc(2026, 4, 2),
          odometerKm: 120000,
          serviceTypeKeys: const [],
        ),
        isFalse,
      );
    });
  });
}
