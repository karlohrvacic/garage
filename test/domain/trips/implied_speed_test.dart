import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/trips/implied_speed.dart';

void main() {
  group('the speed a trip implies', () {
    test('is distance over time', () {
      expect(impliedSpeedKmPerHour(distanceKm: 120, minutes: 90), 80);
    });

    test('is null when the trip was not timed', () {
      expect(impliedSpeedKmPerHour(distanceKm: 120, minutes: null), isNull);
      expect(impliedSpeedKmPerHour(distanceKm: 120, minutes: 0), isNull);
    });

    test('is null when there is no distance to divide', () {
      expect(impliedSpeedKmPerHour(distanceKm: null, minutes: 90), isNull);
    });
  });

  group('whether a speed describes a journey', () {
    test('a motorway run does', () {
      expect(isImplausibleSpeed(118), isFalse);
    });

    test('so does a crawl through town with the clock left running', () {
      expect(isImplausibleSpeed(9), isFalse);
    });

    test('faster than any road vehicle sustains does not', () {
      // 200 km in 30 minutes: minutes typed where hours were meant.
      expect(isImplausibleSpeed(400), isTrue);
    });

    test('slower than walking does not', () {
      // 5 km in eight hours: hours typed where minutes were meant.
      expect(isImplausibleSpeed(0.6), isTrue);
    });

    test('nothing to judge is not a complaint', () {
      expect(isImplausibleSpeed(null), isFalse);
    });
  });
}
