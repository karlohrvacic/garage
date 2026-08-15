import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/tracking_level.dart';

void main() {
  group('reading the setting', () {
    test('maps the keys the household column stores', () {
      expect(TrackingLevel.fromKey('beginner'), TrackingLevel.beginner);
      expect(TrackingLevel.fromKey('intermediate'), TrackingLevel.intermediate);
      expect(TrackingLevel.fromKey('advanced'), TrackingLevel.advanced);
    });

    test('an unknown value falls back to the simplest, not to a crash', () {
      expect(TrackingLevel.fromKey('expert'), TrackingLevel.beginner);
    });

    test('writes back the key it came from', () {
      for (final level in TrackingLevel.values) {
        expect(TrackingLevel.fromKey(level.key), level);
      }
    });
  });

  group('what each level asks for', () {
    test('a beginner is asked for nothing extra', () {
      expect(TrackingLevel.beginner.showsPartsAndLabour, isFalse);
      expect(TrackingLevel.beginner.showsMeasurements, isFalse);
    });

    test('intermediate adds parts, labour, and warranty', () {
      expect(TrackingLevel.intermediate.showsPartsAndLabour, isTrue);
      expect(TrackingLevel.intermediate.showsMeasurements, isFalse);
    });

    test('advanced adds readings on top of that', () {
      expect(TrackingLevel.advanced.showsPartsAndLabour, isTrue);
      expect(TrackingLevel.advanced.showsMeasurements, isTrue);
    });

    test('each level is at least as detailed as the one before', () {
      expect(
        TrackingLevel.beginner.depth,
        lessThan(TrackingLevel.intermediate.depth),
      );
      expect(
        TrackingLevel.intermediate.depth,
        lessThan(TrackingLevel.advanced.depth),
      );
    });
  });

  group('the readings an advanced household can take', () {
    test('cover the wear items that are worth a number', () {
      expect(
        Measurements.all.map((m) => m.key),
        containsAll([
          'brake_pad_front_mm',
          'brake_pad_rear_mm',
          'tread_front_left_mm',
          'tread_front_right_mm',
          'tread_rear_left_mm',
          'tread_rear_right_mm',
          'battery_volts',
        ]),
      );
    });

    test('each carries the unit it is read in', () {
      for (final measurement in Measurements.all) {
        expect(measurement.unit, isNotEmpty);
      }
    });

    test('a stored map keeps only readings that are known and numeric', () {
      final readings = Measurements.fromStored({
        'brake_pad_front_mm': 6.5,
        'battery_volts': 12,
        'something_else': 3,
        'tread_front_left_mm': 'not a number',
      });

      expect(readings, {'brake_pad_front_mm': 6.5, 'battery_volts': 12.0});
    });

    test('an empty map stores as null rather than an empty object', () {
      expect(Measurements.toStored({}), isNull);
      expect(Measurements.toStored({'battery_volts': 12.4}), {
        'battery_volts': 12.4,
      });
    });
  });
}
