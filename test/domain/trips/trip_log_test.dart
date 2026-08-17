import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/trips/trip_log.dart';

TripEntry trip({
  String id = 't1',
  double distanceKm = 100,
  TripPurpose purpose = TripPurpose.private,
  int? minutes,
  int day = 1,
}) {
  return TripEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 3, day),
    distanceKm: distanceKm,
    purpose: purpose,
    minutes: minutes,
    createdBy: 'u1',
  );
}

void main() {
  group('a trip on its own', () {
    test('reports its average speed when it was timed', () {
      expect(trip(distanceKm: 90, minutes: 60).kmPerHour, 90);
    });

    test('reports no speed when it was not timed', () {
      expect(trip(distanceKm: 90).kmPerHour, isNull);
    });

    test('reports no speed for a trip that took no time', () {
      // A typo of zero minutes would otherwise divide by zero and report an
      // infinite average speed.
      expect(trip(distanceKm: 90, minutes: 0).kmPerHour, isNull);
    });
  });

  group('summarising a log', () {
    test('adds up distance, time and trips', () {
      final summary = TripLog.summarise([
        trip(id: 't1', distanceKm: 100, minutes: 60),
        trip(id: 't2', distanceKm: 50, minutes: 30),
      ]);

      expect(summary.trips, 2);
      expect(summary.distanceKm, 150);
      expect(summary.minutes, 90);
    });

    test('splits distance by why the journey was made', () {
      final summary = TripLog.summarise([
        trip(id: 't1', distanceKm: 100, purpose: TripPurpose.business),
        trip(id: 't2', distanceKm: 40, purpose: TripPurpose.private),
        trip(id: 't3', distanceKm: 60, purpose: TripPurpose.business),
      ]);

      expect(summary.businessKm, 160);
      expect(summary.privateKm, 40);
    });

    test('averages speed over the trips that were timed, not all of them', () {
      // Counting untimed trips as zero minutes would report a speed far above
      // anything that was actually driven.
      final summary = TripLog.summarise([
        trip(id: 't1', distanceKm: 100, minutes: 60),
        trip(id: 't2', distanceKm: 500),
      ]);

      expect(summary.kmPerHour, 100);
    });

    test('reports no average speed when nothing was timed', () {
      final summary = TripLog.summarise([trip(distanceKm: 100)]);

      expect(summary.kmPerHour, isNull);
    });

    test('an empty log summarises to nothing rather than to zeroes', () {
      final summary = TripLog.summarise(const []);

      expect(summary.trips, 0);
      expect(summary.distanceKm, 0);
      expect(summary.kmPerHour, isNull);
    });
  });

  group('deriving a distance from an odometer range', () {
    test('is the difference between the two readings', () {
      expect(TripLog.distanceBetween(start: 50000, end: 50188), 188);
    });

    test('is unknown when either end is missing', () {
      expect(TripLog.distanceBetween(start: 50000, end: null), isNull);
      expect(TripLog.distanceBetween(start: null, end: 50188), isNull);
    });

    test('is unknown when the readings go backwards', () {
      // Rather than a negative distance, which would subtract from every total
      // it lands in.
      expect(TripLog.distanceBetween(start: 50188, end: 50000), isNull);
    });
  });
}
