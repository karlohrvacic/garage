import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/import/csv_table.dart';

void main() {
  group('reading a file', () {
    test('takes the first row as the header', () {
      final table = CsvTable.parse('date,odometer\n2026-01-01,1000\n');

      expect(table.headers, ['date', 'odometer']);
      expect(table.rows, [
        ['2026-01-01', '1000'],
      ]);
    });

    test(
      'recognises a semicolon file, which is what a Croatian Excel writes',
      () {
        final table = CsvTable.parse('date;odometer\n2026-01-01;1000\n');

        expect(table.headers, ['date', 'odometer']);
        expect(table.rows.single, ['2026-01-01', '1000']);
      },
    );

    test('recognises a tab-separated file', () {
      final table = CsvTable.parse('date\todometer\n2026-01-01\t1000\n');

      expect(table.headers, ['date', 'odometer']);
    });

    test('picks the delimiter that actually splits the header', () {
      // A comma inside a quoted field must not make this look comma-separated.
      final table = CsvTable.parse('"a;b";c\n1;2\n');

      expect(table.headers, ['a;b', 'c']);
    });

    test('drops a trailing blank line rather than importing an empty row', () {
      final table = CsvTable.parse('date,odometer\n2026-01-01,1000\n\n');

      expect(table.rows, hasLength(1));
    });

    test('pads a short row so a missing trailing column reads as empty', () {
      // Spreadsheets routinely omit trailing empty cells.
      final table = CsvTable.parse('a,b,c\n1,2\n');

      expect(table.rows.single, ['1', '2', '']);
    });

    test('a file with only a header has no rows and does not throw', () {
      final table = CsvTable.parse('date,odometer\n');

      expect(table.headers, hasLength(2));
      expect(table.rows, isEmpty);
    });

    test('an empty file has no headers rather than throwing', () {
      expect(CsvTable.parse('').headers, isEmpty);
    });

    test('strips a byte-order mark off the first header', () {
      // Excel writes one, and it otherwise becomes part of the column name and
      // stops it matching anything.
      final table = CsvTable.parse('﻿date,odometer\n');

      expect(table.headers.first, 'date');
    });
  });

  group('reading a number', () {
    test('reads a plain decimal point', () {
      expect(CsvTable.number('12.5'), 12.5);
    });

    test('reads a decimal comma, which half of Europe writes', () {
      expect(CsvTable.number('12,5'), 12.5);
    });

    test('ignores thousands separators and stray currency', () {
      expect(CsvTable.number('1 234,56 €'), 1234.56);
      expect(CsvTable.number('1,234.56'), 1234.56);
    });

    test('is null for something that is not a number', () {
      expect(CsvTable.number('n/a'), isNull);
      expect(CsvTable.number(''), isNull);
    });
  });

  group('reading a date', () {
    test('reads ISO, which is what an export usually writes', () {
      expect(CsvTable.date('2026-03-09'), DateTime.utc(2026, 3, 9));
    });

    test('reads a timestamp by taking its day', () {
      expect(CsvTable.date('2026-03-09 14:30'), DateTime.utc(2026, 3, 9));
    });

    test('reads day-first, which is what a European spreadsheet writes', () {
      expect(
        CsvTable.date('09/03/2026', dayFirst: true),
        DateTime.utc(2026, 3, 9),
      );
    });

    test('reads month-first when told to', () {
      expect(
        CsvTable.date('03/09/2026', dayFirst: false),
        DateTime.utc(2026, 3, 9),
      );
    });

    test('is null for something that is not a date', () {
      expect(CsvTable.date('last Tuesday'), isNull);
      expect(CsvTable.date(''), isNull);
    });

    test('is null for a date that does not exist', () {
      // 31 February parses as 2 March if the arithmetic is left to DateTime,
      // which would import a fill-up onto the wrong day rather than refusing.
      expect(CsvTable.date('2026-02-31'), isNull);
    });
  });
}
