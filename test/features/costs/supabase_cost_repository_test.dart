import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/costs/data/supabase_cost_repository.dart';

Map<String, dynamic> row({Object? amount = 120.5, Object? odometer = 51140}) {
  return {
    'id': 'c1',
    'vehicle_id': 'v1',
    'entry_date': '2026-06-01',
    'category': CostCategories.insurance,
    'amount': amount,
    'odometer_km': odometer,
    'notes': 'annual policy',
    'created_by': 'u1',
  };
}

CostEntry cost({double amount = 120.5, int? odometerKm = 51140}) {
  return CostEntry(
    id: 'c1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    category: CostCategories.insurance,
    amount: amount,
    odometerKm: odometerKm,
    notes: 'annual policy',
    createdBy: 'u1',
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(costEntryFromRow(row()), cost());
    });

    test('reads the date-only column as UTC midnight', () {
      final date = costEntryFromRow(row()).date;

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 6, 1));
    });

    test('widens an integer amount to double', () {
      expect(costEntryFromRow(row(amount: 120)).amount, 120.0);
    });

    test('an entry logged without an odometer reads as null', () {
      expect(costEntryFromRow(row(odometer: null)).odometerKm, isNull);
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(costEntryToRow(cost()).keys, {
        'entry_date',
        'category',
        'amount',
        'odometer_km',
        'notes',
      });
    });

    test('writes the date as a date-only string', () {
      expect(costEntryToRow(cost())['entry_date'], '2026-06-01');
    });

    test('never sends id or created_by, which the server owns', () {
      final written = costEntryToRow(cost());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = costEntryToRow(cost());
    final reread = costEntryFromRow({
      ...written,
      'id': 'c1',
      'vehicle_id': 'v1',
      'created_by': 'u1',
    });

    expect(reread, cost());
  });
}
