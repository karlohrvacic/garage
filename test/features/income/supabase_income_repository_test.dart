import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/features/income/data/supabase_income_repository.dart';

Map<String, dynamic> row({
  Object? amount = 4500.0,
  Object? odometer = 120000,
  Object? by = 'u1',
}) {
  return {
    'id': 'i1',
    'vehicle_id': 'v1',
    'entry_date': '2026-06-01',
    'category': IncomeCategories.ride,
    'amount': amount,
    'odometer_km': odometer,
    'notes': 'shared the drive to Zagreb',
    'created_by': ?by,
  };
}

IncomeEntry income({double amount = 4500.0, int? odometerKm = 120000}) {
  return IncomeEntry(
    id: 'i1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    category: IncomeCategories.ride,
    amount: amount,
    odometerKm: odometerKm,
    notes: 'shared the drive to Zagreb',
    createdBy: 'u1',
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(incomeEntryFromRow(row()), income());
    });

    test('reads the date-only column as UTC midnight', () {
      final date = incomeEntryFromRow(row()).date;

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 6, 1));
    });

    test('widens an integer amount to double', () {
      // Postgres `numeric` arrives as int when the value happens to be whole,
      // which is exactly what a sale price usually is.
      expect(incomeEntryFromRow(row(amount: 4500)).amount, 4500.0);
    });

    test('money recorded without an odometer reads as null', () {
      expect(incomeEntryFromRow(row(odometer: null)).odometerKm, isNull);
    });

    test('an entry whose author has since been deleted still reads', () {
      expect(incomeEntryFromRow(row(by: null)).createdBy, '');
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(incomeEntryToRow(income()).keys, {
        'entry_date',
        'category',
        'amount',
        'odometer_km',
        'notes',
      });
    });

    test('writes the date as a date-only string', () {
      expect(incomeEntryToRow(income())['entry_date'], '2026-06-01');
    });

    test('never sends id or created_by, which the server owns', () {
      final written = incomeEntryToRow(income());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
      expect(written.containsKey('vehicle_id'), isFalse);
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = incomeEntryToRow(income());
    final reread = incomeEntryFromRow({
      ...written,
      'id': 'i1',
      'vehicle_id': 'v1',
      'created_by': 'u1',
    });

    expect(reread, income());
  });
}
