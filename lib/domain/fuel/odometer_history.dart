/// One sighting of a vehicle's odometer, whatever produced it: a fill-up, a
/// service visit, a cost entry that recorded a reading, or a reading logged on
/// its own.
class OdometerSample {
  const OdometerSample({required this.date, required this.km});

  /// UTC, like every other date in the domain layer.
  final DateTime date;

  final int km;

  @override
  bool operator ==(Object other) =>
      other is OdometerSample && other.date == date && other.km == km;

  @override
  int get hashCode => Object.hash(date, km);

  @override
  String toString() => 'OdometerSample(date: $date, km: $km)';
}

/// A vehicle's odometer as one series, merged from every source that records
/// one.
///
/// Reading the odometer only from fill-ups was a real defect: a household that
/// logs services but pays cash at the pump had nothing to measure, so every
/// distance-based projection fell back to the assumed daily rate. The fix is
/// not more sources at the call site but one place that knows what a reading
/// is, wherever it came from.
abstract final class OdometerHistory {
  /// The readings as a usable series: oldest first, one reading per day, and
  /// nothing that goes backwards.
  ///
  /// Two rules earn their place here. Several entries on one day are normal —
  /// a fill-up and the service that prompted it — and keeping both would put
  /// two points zero days apart into any rate taken from the series. And a
  /// reading lower than one already recorded means one of the two is a typo;
  /// which one is unknowable, so the later one is dropped and the series stays
  /// monotonic rather than reporting that the car drove backwards.
  static List<OdometerSample> sorted(Iterable<OdometerSample> samples) {
    final byDay = <DateTime, int>{};
    for (final sample in samples) {
      final day = DateTime.utc(
        sample.date.year,
        sample.date.month,
        sample.date.day,
      );
      final existing = byDay[day];
      if (existing == null || sample.km > existing) {
        byDay[day] = sample.km;
      }
    }

    final days = byDay.keys.toList()..sort();
    final series = <OdometerSample>[];
    for (final day in days) {
      final km = byDay[day]!;
      if (series.isNotEmpty && km <= series.last.km) {
        continue;
      }
      series.add(OdometerSample(date: day, km: km));
    }
    return series;
  }

  /// Where the vehicle stands now: the highest reading anything has seen, and
  /// never below the baseline the owner gave when they added the car.
  static int currentKm({
    required int baselineKm,
    required Iterable<OdometerSample> samples,
  }) {
    var current = baselineKm;
    for (final sample in samples) {
      if (sample.km > current) {
        current = sample.km;
      }
    }
    return current;
  }

  /// Average daily distance across the whole series, or null when there is
  /// nothing to measure: fewer than two usable readings, no time between them,
  /// or no distance covered.
  ///
  /// Null rather than a guess, so the caller decides what an unmeasurable rate
  /// should mean rather than being handed a number that looks measured.
  static double? kmPerDay(Iterable<OdometerSample> samples) {
    final series = sorted(samples);
    if (series.length < 2) {
      return null;
    }
    final distance = series.last.km - series.first.km;
    final days = series.last.date.difference(series.first.date).inDays;
    if (days <= 0 || distance <= 0) {
      return null;
    }
    return distance / days;
  }
}
