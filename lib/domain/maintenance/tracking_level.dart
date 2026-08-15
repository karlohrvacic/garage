/// How much detail a household wants to be asked for.
///
/// The data model does not change with the level — a beginner and an
/// enthusiast log the same service entry, one with more of its fields filled
/// in. This only decides what the sheet puts on screen, so a household can
/// deepen its records later without migrating anything.
enum TrackingLevel {
  /// Date, odometer, what was done, what it cost.
  beginner('beginner', 0),

  /// Adds the parts used, the split between parts and labour, whether it was
  /// done at home, and any warranty on the work.
  intermediate('intermediate', 1),

  /// Adds readings: pad thickness, tread depth, battery voltage — the numbers
  /// that only mean something as a series.
  advanced('advanced', 2);

  const TrackingLevel(this.key, this.depth);

  final String key;

  /// Ordering, so a feature can ask for "intermediate or deeper".
  final int depth;

  bool get showsPartsAndLabour => depth >= TrackingLevel.intermediate.depth;

  bool get showsMeasurements => depth >= TrackingLevel.advanced.depth;

  /// The level for a stored key. Anything unrecognised reads as the simplest
  /// one: a household should never be shown fields it did not ask for because
  /// of a value this version does not know.
  static TrackingLevel fromKey(String key) {
    for (final level in values) {
      if (level.key == key) {
        return level;
      }
    }
    return TrackingLevel.beginner;
  }
}

/// One number worth taking during a service.
class Measurement {
  const Measurement({required this.key, required this.unit});

  /// Language-neutral id, stored as a key in the entry's measurement map.
  final String key;

  final String unit;
}

/// The readings an advanced household can record against a service.
///
/// Wear items that are only meaningful as a series: a single 6 mm brake pad
/// says little, three readings across a year say when to buy pads.
abstract final class Measurements {
  static const all = [
    Measurement(key: 'brake_pad_front_mm', unit: 'mm'),
    Measurement(key: 'brake_pad_rear_mm', unit: 'mm'),
    Measurement(key: 'brake_disc_front_mm', unit: 'mm'),
    Measurement(key: 'tread_front_left_mm', unit: 'mm'),
    Measurement(key: 'tread_front_right_mm', unit: 'mm'),
    Measurement(key: 'tread_rear_left_mm', unit: 'mm'),
    Measurement(key: 'tread_rear_right_mm', unit: 'mm'),
    Measurement(key: 'battery_volts', unit: 'V'),
    Measurement(key: 'battery_cca', unit: 'A'),
  ];

  static const _knownKeys = {
    'brake_pad_front_mm',
    'brake_pad_rear_mm',
    'brake_disc_front_mm',
    'tread_front_left_mm',
    'tread_front_right_mm',
    'tread_rear_left_mm',
    'tread_rear_right_mm',
    'battery_volts',
    'battery_cca',
  };

  /// Readings out of a stored map, dropping anything this version does not
  /// know or that is not a number — the column is free-form JSON, and a bad
  /// value should cost one reading rather than the whole entry.
  static Map<String, double> fromStored(Map<String, dynamic>? stored) {
    if (stored == null) {
      return const {};
    }
    return {
      for (final entry in stored.entries)
        if (_knownKeys.contains(entry.key) && entry.value is num)
          entry.key: (entry.value as num).toDouble(),
    };
  }

  /// What to write back. Nothing recorded stores as null rather than `{}`, so
  /// "no readings" reads the same whether the household ever took any.
  static Map<String, double>? toStored(Map<String, double> readings) {
    return readings.isEmpty ? null : Map.of(readings);
  }
}
