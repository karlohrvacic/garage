import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/supabase/date_column.dart';

void main() {
  test('a date column reads back as UTC midnight', () {
    final date = dateFromColumn('2026-07-24');

    expect(date, DateTime.utc(2026, 7, 24));
    expect(date.isUtc, isTrue);
  });

  test('a UTC date writes as its calendar day', () {
    expect(dateToColumn(DateTime.utc(2026, 7, 24)), '2026-07-24');
  });

  test('a local date writes as the calendar day the user picked', () {
    expect(dateToColumn(DateTime(2026, 7, 24, 23, 30)), '2026-07-24');
  });

  test('the round trip keeps the day and the UTC flag', () {
    final original = DateTime.utc(2026, 1, 1);

    expect(dateFromColumn(dateToColumn(original)), original);
  });
}
