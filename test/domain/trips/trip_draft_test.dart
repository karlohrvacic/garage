import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_draft.dart';
import 'package:garage/domain/entities/trip_entry.dart';

TripDraft draft({
  DateTime? startedAt,
  int? startOdometerKm = 142300,
  String? driver,
  String? fromPlace,
}) {
  return TripDraft(
    id: 't1',
    vehicleId: 'v1',
    startedAt: startedAt ?? DateTime.utc(2026, 9, 5, 7, 12),
    startOdometerKm: startOdometerKm,
    createdBy: 'u1',
    driver: driver,
    fromPlace: fromPlace,
  );
}

void main() {
  group('finishing a drive', () {
    test('the distance is the odometer range when both ends are known', () {
      final trip = finishDraft(
        draft(),
        endedAt: DateTime.utc(2026, 9, 5, 8, 7),
        endOdometerKm: 142343,
      );

      expect(trip.distanceKm, 43);
    });

    test('a distance stated outright wins over the odometer range', () {
      // The odometer is whole kilometres; a driver claiming 43.6 has a better
      // figure than the dashboard rounded off.
      final trip = finishDraft(
        draft(),
        endedAt: DateTime.utc(2026, 9, 5, 8, 7),
        endOdometerKm: 142343,
        distanceKm: 43.6,
      );

      expect(trip.distanceKm, 43.6);
    });

    test('the duration is the time the drive was actually open', () {
      final trip = finishDraft(
        draft(startedAt: DateTime.utc(2026, 9, 5, 7, 12)),
        endedAt: DateTime.utc(2026, 9, 5, 8, 7),
        endOdometerKm: 142343,
      );

      expect(trip.minutes, 55);
    });

    test(
      'a stated duration wins, for the drive that sat parked mid-errand',
      () {
        final trip = finishDraft(
          draft(),
          endedAt: DateTime.utc(2026, 9, 5, 9, 30),
          endOdometerKm: 142343,
          minutes: 40,
        );

        expect(trip.minutes, 40);
      },
    );

    test('seconds round to the nearest minute rather than truncating', () {
      final trip = finishDraft(
        draft(startedAt: DateTime.utc(2026, 9, 5, 7, 0)),
        endedAt: DateTime.utc(2026, 9, 5, 7, 10, 40),
        endOdometerKm: 142310,
      );

      expect(trip.minutes, 11);
    });

    test(
      'a clock that went backwards yields no duration, not a negative one',
      () {
        // Phones change time zone mid-journey and users edit the arrival time.
        // A negative duration would fail the database check and reads as a bug.
        final trip = finishDraft(
          draft(startedAt: DateTime.utc(2026, 9, 5, 8, 0)),
          endedAt: DateTime.utc(2026, 9, 5, 7, 0),
          endOdometerKm: 142343,
        );

        expect(trip.minutes, isNull);
      },
    );

    test('the trip is dated the day it set off, not the day it arrived', () {
      // A drive over midnight belongs to the evening it began: that is the day
      // the driver will look for it under, and the day a logbook names.
      //
      // Written in local time on purpose: a fixture in UTC would assert the
      // right answer only in the one time zone that has no offset.
      final trip = finishDraft(
        draft(startedAt: DateTime(2026, 9, 5, 23, 40).toUtc()),
        endedAt: DateTime(2026, 9, 6, 0, 55).toUtc(),
        endOdometerKm: 142400,
      );

      expect(trip.date, DateTime.utc(2026, 9, 5));
    });

    test('a drive begun just after midnight is dated that day, not the one '
        'before', () {
      // East of Greenwich, half past midnight is still yesterday in UTC.
      // Reading the calendar fields off the UTC instant dated the drive to the
      // day before — for every driver in Croatia, one night in three hundred.
      final trip = finishDraft(
        draft(startedAt: DateTime(2026, 9, 6, 0, 30).toUtc()),
        endedAt: DateTime(2026, 9, 6, 1, 10).toUtc(),
        endOdometerKm: 142400,
      );

      expect(trip.date, DateTime.utc(2026, 9, 6));
    });

    test('what the draft already knew is carried through', () {
      final trip = finishDraft(
        draft(driver: 'Ana', fromPlace: 'Zagreb'),
        endedAt: DateTime.utc(2026, 9, 5, 8, 7),
        endOdometerKm: 142343,
        toPlace: 'Karlovac',
      );

      expect(trip.id, 't1');
      expect(trip.vehicleId, 'v1');
      expect(trip.createdBy, 'u1');
      expect(trip.driver, 'Ana');
      expect(trip.fromPlace, 'Zagreb');
      expect(trip.toPlace, 'Karlovac');
      expect(trip.startOdometerKm, 142300);
      expect(trip.endOdometerKm, 142343);
    });

    test('the purpose defaults to private and can be set on finishing', () {
      expect(
        finishDraft(
          draft(),
          endedAt: DateTime.utc(2026, 9, 5, 8, 7),
          endOdometerKm: 142343,
        ).purpose,
        TripPurpose.private,
      );
      expect(
        finishDraft(
          draft(),
          endedAt: DateTime.utc(2026, 9, 5, 8, 7),
          endOdometerKm: 142343,
          purpose: TripPurpose.business,
        ).purpose,
        TripPurpose.business,
      );
    });

    test(
      'a drive with no odometer at either end still finishes on a distance',
      () {
        // Somebody who never noted the starting reading can still record that
        // they drove 12 km. Refusing the trip would lose the journey entirely.
        final trip = finishDraft(
          draft(startOdometerKm: null),
          endedAt: DateTime.utc(2026, 9, 5, 8, 7),
          distanceKm: 12,
        );

        expect(trip.distanceKm, 12);
        expect(trip.startOdometerKm, isNull);
        expect(trip.endOdometerKm, isNull);
      },
    );

    test('nothing to go on is refused rather than logged as a zero', () {
      // No distance and no odometer range is not a journey of length zero, it
      // is a journey nobody measured, and a silent 0 corrupts every average
      // that reads it.
      expect(
        () => finishDraft(
          draft(startOdometerKm: null),
          endedAt: DateTime.utc(2026, 9, 5, 8, 7),
        ),
        throwsArgumentError,
      );
    });

    test('an odometer that went backwards is refused', () {
      expect(
        () => finishDraft(
          draft(),
          endedAt: DateTime.utc(2026, 9, 5, 8, 7),
          endOdometerKm: 142299,
        ),
        throwsArgumentError,
      );
    });
  });

  group('how long a drive has been open', () {
    test('is measured against now', () {
      final open = draft(startedAt: DateTime.utc(2026, 9, 5, 7, 12));

      expect(
        open.elapsedAt(DateTime.utc(2026, 9, 5, 8, 12)),
        const Duration(hours: 1),
      );
    });

    test('never runs backwards, however the clock behaves', () {
      final open = draft(startedAt: DateTime.utc(2026, 9, 5, 8, 0));

      expect(open.elapsedAt(DateTime.utc(2026, 9, 5, 7, 0)), Duration.zero);
    });
  });
}
