import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';

VehicleAssignment assignment({
  String? userId = 'ana',
  DateTime? fromDate,
  DateTime? toDate,
  DateTime? confirmedAt,
}) {
  return VehicleAssignment(
    id: 'a1',
    vehicleId: 'v1',
    userId: userId,
    fromDate: fromDate ?? DateTime.utc(2026, 5, 1),
    toDate: toDate,
    handoverOdometerKm: 120000,
    createdBy: 'admin',
  );
}

void main() {
  group('the window', () {
    test('holds both of its ends', () {
      final closed = assignment(toDate: DateTime.utc(2026, 5, 31));

      expect(closed.covers(DateTime.utc(2026, 5, 1)), isTrue);
      expect(closed.covers(DateTime.utc(2026, 5, 31)), isTrue);
      expect(closed.covers(DateTime.utc(2026, 4, 30)), isFalse);
      expect(closed.covers(DateTime.utc(2026, 6, 1)), isFalse);
    });

    test('an open one has no end', () {
      expect(assignment().isOpen, isTrue);
      expect(assignment().covers(DateTime.utc(2031, 1, 1)), isTrue);
    });

    test('a local evening is still its own date', () {
      // West of UTC the instant is already the next day in UTC; the driver
      // had the car on the day they saw.
      final closed = assignment(toDate: DateTime.utc(2026, 5, 31));

      expect(closed.covers(DateTime(2026, 5, 31, 23, 59)), isTrue);
      expect(closed.covers(DateTime(2026, 4, 30, 23, 59)), isFalse);
    });

    test('and so are its own ends, built from a local date', () {
      // The rows arrive as UTC days, but a window built from a date picker
      // carries a local instant. Judged as instants, a window opened on a
      // local evening would miss its own first day.
      final closed = assignment(
        fromDate: DateTime(2026, 5, 1, 23, 59),
        toDate: DateTime(2026, 5, 31, 23, 59),
      );

      expect(closed.covers(DateTime.utc(2026, 5, 1)), isTrue);
      expect(closed.covers(DateTime.utc(2026, 5, 31)), isTrue);
      expect(closed.covers(DateTime.utc(2026, 4, 30)), isFalse);
      expect(closed.covers(DateTime.utc(2026, 6, 1)), isFalse);
    });
  });

  group('the sign-off', () {
    test('is missing until the driver confirms', () {
      expect(assignment().isConfirmed, isFalse);
      expect(
        assignment()
            .copyWith(confirmedAt: DateTime.utc(2026, 5, 2))
            .isConfirmed,
        isTrue,
      );
    });
  });

  group('copyWith', () {
    test('closes a window without touching the rest', () {
      final returned = assignment().copyWith(
        toDate: DateTime.utc(2026, 5, 31),
        returnOdometerKm: 121500,
      );

      expect(returned.isOpen, isFalse);
      expect(returned.returnOdometerKm, 121500);
      expect(returned.handoverOdometerKm, 120000);
      expect(returned.userId, 'ana');
    });

    test('can reopen one, which a plain null could never say', () {
      final closed = assignment(toDate: DateTime.utc(2026, 5, 31));

      expect(closed.copyWith().isOpen, isFalse);
      expect(closed.copyWith(clearToDate: true).isOpen, isTrue);
    });
  });

  group('equality', () {
    test('field-identical instances are equal and share a hash code', () {
      expect(assignment(), assignment());
      expect(assignment().hashCode, assignment().hashCode);
    });

    test('a differing end breaks equality', () {
      expect(
        assignment(toDate: DateTime.utc(2026, 5, 31)),
        isNot(assignment()),
      );
    });

    test('a deleted account is a different window from a named one', () {
      expect(assignment(userId: null), isNot(assignment()));
    });

    test('toString names the type and the driver', () {
      expect(assignment().toString(), contains('VehicleAssignment('));
      expect(assignment().toString(), contains('ana'));
    });
  });
}
