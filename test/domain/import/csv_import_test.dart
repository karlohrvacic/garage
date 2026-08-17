import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/import/csv_import.dart';
import 'package:garage/domain/import/csv_table.dart';

void main() {
  group('what a kind needs', () {
    test('a fill-up needs a date, an odometer and a volume', () {
      final required = CsvSchema.fieldsFor(
        CsvEntryKind.fuel,
      ).where((f) => f.required).map((f) => f.key);

      expect(required, containsAll(['date', 'odometer', 'volume']));
    });

    test('a reading needs nothing but a date and an odometer', () {
      final fields = CsvSchema.fieldsFor(CsvEntryKind.odometer);

      expect(fields.map((f) => f.key), ['date', 'odometer', 'notes']);
    });

    test('every kind can be imported', () {
      for (final kind in CsvEntryKind.values) {
        expect(CsvSchema.fieldsFor(kind), isNotEmpty, reason: '$kind');
      }
    });
  });

  group('guessing which column is which', () {
    test('matches a header by its own name', () {
      final guess = CsvSchema.guess(CsvEntryKind.fuel, [
        'date',
        'odometer',
        'volume',
      ]);

      expect(guess['date'], 0);
      expect(guess['odometer'], 1);
      expect(guess['volume'], 2);
    });

    test('matches through the words another app would use', () {
      final guess = CsvSchema.guess(CsvEntryKind.fuel, [
        'Data',
        'Odo (km)',
        'Litres',
        'Price/l',
        'Total cost',
      ]);

      expect(guess['odometer'], 1);
      expect(guess['volume'], 2);
      expect(guess['pricePerUnit'], 3);
      expect(guess['total'], 4);
    });

    test('ignores case and punctuation in a header', () {
      final guess = CsvSchema.guess(CsvEntryKind.fuel, ['ODOMETER_KM']);

      expect(guess['odometer'], 0);
    });

    test('leaves a field unmapped rather than guessing wildly', () {
      final guess = CsvSchema.guess(CsvEntryKind.fuel, ['alpha', 'beta']);

      expect(guess, isEmpty);
    });

    test('never maps two fields onto the same column', () {
      // "Cost" could plausibly answer to both the total and the price; the
      // first field to claim a column keeps it.
      final guess = CsvSchema.guess(CsvEntryKind.cost, ['date', 'cost']);

      expect(guess.values.toSet(), hasLength(guess.length));
    });
  });

  group('building rows', () {
    final table = CsvTable.parse(
      'when;km;litres;paid\n'
      '09/03/2026;1000;40,5;62,30\n'
      '23/03/2026;1500;38;58\n',
    );
    const mapping = {'date': 0, 'odometer': 1, 'volume': 2, 'total': 3};

    test('reads every row into typed values', () {
      final result = CsvImport.build(
        kind: CsvEntryKind.fuel,
        table: table,
        mapping: mapping,
      );

      expect(result.rows, hasLength(2));
      expect(result.rows.first['date'], DateTime.utc(2026, 3, 9));
      expect(result.rows.first['odometer'], 1000);
      expect(result.rows.first['volume'], 40.5);
      expect(result.rows.first['total'], 62.30);
      expect(result.problems, isEmpty);
    });

    test('refuses to build when a required field is unmapped', () {
      final result = CsvImport.build(
        kind: CsvEntryKind.fuel,
        table: table,
        mapping: const {'date': 0},
      );

      expect(result.rows, isEmpty);
      expect(
        result.problems.map((p) => p.field),
        containsAll(['odometer', 'volume']),
      );
    });

    test('skips a row whose required value will not parse, and says which', () {
      final broken = CsvTable.parse(
        'when;km;litres\n'
        '09/03/2026;1000;40\n'
        'not a date;1500;38\n',
      );

      final result = CsvImport.build(
        kind: CsvEntryKind.fuel,
        table: broken,
        mapping: const {'date': 0, 'odometer': 1, 'volume': 2},
      );

      expect(result.rows, hasLength(1));
      expect(result.problems.single.rowNumber, 3);
      expect(result.problems.single.field, 'date');
    });

    test('leaves an optional value out rather than failing the row', () {
      final sparse = CsvTable.parse(
        'when;km;litres;paid\n09/03/2026;1000;40;\n',
      );

      final result = CsvImport.build(
        kind: CsvEntryKind.fuel,
        table: sparse,
        mapping: mapping,
      );

      expect(result.rows.single.containsKey('total'), isFalse);
      expect(result.problems, isEmpty);
    });

    test('reads a flag from the words people actually write', () {
      final flags = CsvTable.parse(
        'when;km;litres;full\n'
        '09/03/2026;1000;40;yes\n'
        '10/03/2026;1100;20;0\n'
        '11/03/2026;1200;30;TRUE\n',
      );

      final result = CsvImport.build(
        kind: CsvEntryKind.fuel,
        table: flags,
        mapping: const {'date': 0, 'odometer': 1, 'volume': 2, 'fullTank': 3},
      );

      expect(result.rows.map((r) => r['fullTank']), [true, false, true]);
    });

    test('a month-first file is read month-first when told', () {
      final result = CsvImport.build(
        kind: CsvEntryKind.fuel,
        table: table,
        mapping: mapping,
        dayFirst: false,
      );

      // 09/03 read as September the 3rd.
      expect(result.rows.first['date'], DateTime.utc(2026, 9, 3));
    });
  });
}
