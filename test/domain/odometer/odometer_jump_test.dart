import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/odometer/odometer_jump.dart';

void main() {
  DateTime day(int d) => DateTime.utc(2026, 9, d);

  group('what two readings imply', () {
    test('an ordinary week is not questioned', () {
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 120400,
          toDate: day(8),
        ),
        isFalse,
      );
    });

    test('a very long single day is still a day somebody had', () {
      // Zagreb to Munich and back is real, and an app that questioned it
      // would be ignored by the time it had something worth saying.
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 121400,
          toDate: day(2),
        ),
        isFalse,
      );
    });

    test('a delivery driver at 700 km a day for a month is left alone', () {
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 141000,
          toDate: day(30),
        ),
        isFalse,
      );
    });

    test('a digit typed twice is caught', () {
      // 124,000 typed as 1,240,000 the day after a reading of 123,900.
      expect(
        isImplausibleJump(
          fromKm: 123900,
          fromDate: day(1),
          toKm: 1240000,
          toDate: day(2),
        ),
        isTrue,
      );
    });

    test('a month of gap does not excuse a decimal place', () {
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 1200000,
          toDate: day(30),
        ),
        isTrue,
      );
    });

    test('two readings on the same day are judged as one day', () {
      // A reading taken twice in a morning has no elapsed time to divide by,
      // and a plain per-day rate would call every one of them impossible.
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 120300,
          toDate: day(1),
        ),
        isFalse,
      );
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 900000,
          toDate: day(1),
        ),
        isTrue,
      );
    });

    test('a reading that goes backwards is not this check\'s business', () {
      // The sheets refuse it outright; saying "implausible jump" about it
      // would put two different sentences on the same mistake.
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(1),
          toKm: 119000,
          toDate: day(2),
        ),
        isFalse,
      );
    });

    test('there is nothing to compare against without a previous reading', () {
      expect(
        isImplausibleJump(
          fromKm: null,
          fromDate: null,
          toKm: 120000,
          toDate: day(1),
        ),
        isFalse,
      );
    });

    test('a reading dated before the one it follows is not judged', () {
      expect(
        isImplausibleJump(
          fromKm: 120000,
          fromDate: day(8),
          toKm: 120400,
          toDate: day(1),
        ),
        isFalse,
      );
    });
  });
}
