import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/trips/route_trend.dart';

TripEntry run({
  required DateTime date,
  required int? minutes,
  String routeId = 'r1',
  bool comparable = true,
  DateTime? startedAt,
  String? driver,
  double distanceKm = 20,
}) {
  return TripEntry(
    id: '${date.toIso8601String()}-$minutes',
    vehicleId: 'v1',
    date: date,
    distanceKm: distanceKm,
    purpose: TripPurpose.private,
    createdBy: 'u1',
    minutes: minutes,
    routeId: routeId,
    comparable: comparable,
    startedAt: startedAt,
    driver: driver,
  );
}

void main() {
  group('which journeys count', () {
    test('a journey with no duration cannot be compared on time', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 1), minutes: 35),
        run(date: DateTime.utc(2026, 5, 2), minutes: null),
      ]);

      expect(trend.sampleCount, 1);
    });

    test('one marked not a normal run is left out of the trend', () {
      // The shopping detour. Excluded by default so it cannot quietly drag a
      // median, and still available to draw.
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 1), minutes: 35),
        run(date: DateTime.utc(2026, 5, 2), minutes: 95, comparable: false),
      ]);

      expect(trend.sampleCount, 1);
      expect(trend.excluded, hasLength(1));
      expect(trend.overallMedian, 35);
    });

    test('nothing recorded is an empty trend, not a crash', () {
      final trend = summariseRoute(const []);

      expect(trend.sampleCount, 0);
      expect(trend.overallMedian, isNull);
      expect(trend.buckets, isEmpty);
    });
  });

  group('the middle journey, not the average one', () {
    test('the median ignores the one stuck behind a crash', () {
      // A mean of these is 46; the median is 35, which is what the drive
      // actually takes.
      final trend = summariseRoute([
        for (final m in [34, 35, 36, 120])
          run(date: DateTime.utc(2026, 5, 1), minutes: m),
      ]);

      expect(trend.overallMedian, 35.5);
    });

    test('an even sample takes the middle pair', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 1), minutes: 30),
        run(date: DateTime.utc(2026, 5, 2), minutes: 40),
      ]);

      expect(trend.overallMedian, 35);
    });

    test('spread is reported, because a median alone hides it', () {
      // Quartiles by linear interpolation, the definition most tools use,
      // rather than the median-of-halves one. On the small samples this
      // feature actually sees, interpolation moves smoothly as a journey is
      // added instead of jumping between recorded values.
      final trend = summariseRoute([
        for (final m in [30, 35, 40, 45])
          run(date: DateTime.utc(2026, 5, 1), minutes: m),
      ]);

      expect(trend.overallLow, 33.75);
      expect(trend.overallHigh, 41.25);
    });
  });

  group('buckets over time', () {
    test('journeys group by quarter, oldest first', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2024, 2, 1), minutes: 35),
        run(date: DateTime.utc(2024, 3, 1), minutes: 35),
        run(date: DateTime.utc(2026, 8, 1), minutes: 45),
      ], grouping: RouteGrouping.quarter);

      expect(trend.buckets.map((it) => it.label), ['2024 Q1', '2026 Q3']);
      expect(trend.buckets.first.median, 35);
      expect(trend.buckets.last.median, 45);
    });

    test('and by month when asked', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 1), minutes: 35),
        run(date: DateTime.utc(2026, 6, 1), minutes: 45),
      ], grouping: RouteGrouping.month);

      expect(trend.buckets.map((it) => it.label), ['2026-05', '2026-06']);
    });

    test('every bucket says how many journeys it rests on', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 1), minutes: 35),
        run(date: DateTime.utc(2026, 5, 2), minutes: 37),
        run(date: DateTime.utc(2026, 6, 1), minutes: 45),
      ], grouping: RouteGrouping.month);

      expect(trend.buckets.map((it) => it.count), [2, 1]);
    });

    test('a thin bucket says so rather than drawing a confident line', () {
      // Three journeys is not a trend, and a chart that looks the same at
      // n=3 and n=300 is a chart that misleads.
      final trend = summariseRoute([
        for (var day = 1; day <= 3; day++)
          run(date: DateTime.utc(2026, 5, day), minutes: 35),
        for (var day = 1; day <= 8; day++)
          run(date: DateTime.utc(2026, 6, day), minutes: 45),
      ], grouping: RouteGrouping.month);

      expect(trend.buckets.first.sparse, isTrue);
      expect(trend.buckets.last.sparse, isFalse);
    });
  });

  group('comparing like with like', () {
    test('a weekday filter drops the weekend runs', () {
      // Saturday 2026-05-02, Monday 2026-05-04.
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 2), minutes: 20),
        run(date: DateTime.utc(2026, 5, 4), minutes: 45),
      ], weekdaysOnly: true);

      expect(trend.sampleCount, 1);
      expect(trend.overallMedian, 45);
    });

    test('a departure window keeps only journeys that started in it', () {
      final trend = summariseRoute(
        [
          // Local, not UTC: a departure window is a wall-clock question
          // where the driver is, and a UTC fixture would make this test pass
          // or fail depending on the machine's time zone.
          run(
            date: DateTime.utc(2026, 5, 4),
            minutes: 45,
            startedAt: DateTime(2026, 5, 4, 7, 30),
          ),
          run(
            date: DateTime.utc(2026, 5, 5),
            minutes: 25,
            startedAt: DateTime(2026, 5, 5, 11),
          ),
        ],
        departureFrom: 7,
        departureTo: 9,
      );

      expect(trend.sampleCount, 1);
      expect(trend.overallMedian, 45);
    });

    test('a journey with no start time cannot answer a window question', () {
      // Trips typed in afterwards have no departure time. Counting them in a
      // window they might not belong to would be inventing the answer.
      final trend = summariseRoute(
        [run(date: DateTime.utc(2026, 5, 4), minutes: 45)],
        departureFrom: 7,
        departureTo: 9,
      );

      expect(trend.sampleCount, 0);
      expect(trend.droppedForNoStartTime, 1);
    });

    test('but counts fine when no window was asked for', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 4), minutes: 45),
      ]);

      expect(trend.sampleCount, 1);
      expect(trend.droppedForNoStartTime, 0);
    });

    test('one driver at a time, because two people drive differently', () {
      final trend = summariseRoute([
        run(date: DateTime.utc(2026, 5, 4), minutes: 45, driver: 'Ana'),
        run(date: DateTime.utc(2026, 5, 5), minutes: 60, driver: 'Ivan'),
      ], driver: 'Ana');

      expect(trend.sampleCount, 1);
      expect(trend.overallMedian, 45);
    });
  });

  group('what it may claim', () {
    test(
      'the change between the first and last bucket is reported plainly',
      () {
        final trend = summariseRoute([
          for (var day = 1; day <= 6; day++)
            run(date: DateTime.utc(2024, 5, day), minutes: 35),
          for (var day = 1; day <= 6; day++)
            run(date: DateTime.utc(2026, 5, day), minutes: 45),
        ], grouping: RouteGrouping.quarter);

        expect(trend.changeInMinutes, 10);
      },
    );

    test('with one bucket there is no change to report', () {
      // A single quarter cannot show a trend, and printing "+0" would imply
      // it had been measured against something.
      final trend = summariseRoute([
        for (var day = 1; day <= 6; day++)
          run(date: DateTime.utc(2026, 5, day), minutes: 35),
      ], grouping: RouteGrouping.quarter);

      expect(trend.changeInMinutes, isNull);
    });

    test(
      'a change resting on a thin bucket is still reported, and flagged',
      () {
        final trend = summariseRoute([
          run(date: DateTime.utc(2024, 5, 1), minutes: 35),
          for (var day = 1; day <= 6; day++)
            run(date: DateTime.utc(2026, 5, day), minutes: 45),
        ], grouping: RouteGrouping.quarter);

        expect(trend.changeInMinutes, 10);
        expect(trend.restsOnSparseData, isTrue);
      },
    );
  });
}
