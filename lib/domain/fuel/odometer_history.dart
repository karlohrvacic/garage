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

  /// How much recent driving the rate is taken from, when there is enough of
  /// it. Three months: long enough that one holiday does not double the
  /// figure, short enough to follow a car that changed hands or changed job.
  static const int rateWindowDays = 90;

  /// The shortest window worth preferring to the whole series.
  ///
  /// Two fills a week apart on a road trip are a real measurement of a week
  /// nobody repeats, and without this they would treble every distance
  /// projection the car has.
  static const int _minimumWindowDays = 21;

  /// Average daily distance from recent driving, or null when there is nothing
  /// to measure: fewer than two usable readings, no time between them, or no
  /// distance covered.
  ///
  /// **Recent, not lifetime.** Taking the whole series divides a car's total
  /// distance by its total age, so a vehicle imported with four years of
  /// history barely moves its rate when its owner starts commuting — and every
  /// distance-based due date it has is then months out, all in the same
  /// direction. The last [rateWindowDays] answer the question the projection
  /// actually asks: at the rate this car is being driven *now*, when does it
  /// reach that odometer.
  ///
  /// The whole series is the fallback, not the default. A car logged twice a
  /// year has no usable window, and a car added last week has no history but
  /// the fortnight it has — both are better served by their own thin series
  /// than by the assumed rate.
  ///
  /// Null rather than a guess, so the caller decides what an unmeasurable rate
  /// should mean rather than being handed a number that looks measured.
  static double? kmPerDay(Iterable<OdometerSample> samples) {
    final series = sorted(samples);
    return _rateOver(_window(series), minimumDays: _minimumWindowDays) ??
        _rateOver(series);
  }

  /// The tail of [series] within [rateWindowDays] of its own last reading.
  ///
  /// Anchored to the last reading rather than to today, so the function stays
  /// pure and a car parked for a year reports the rate it was driven at rather
  /// than nothing at all — which is also what the projection's own
  /// "current odometer" already assumes.
  static List<OdometerSample> _window(List<OdometerSample> series) {
    if (series.isEmpty) {
      return series;
    }
    final from = series.last.date.subtract(
      const Duration(days: rateWindowDays),
    );
    return [
      for (final sample in series)
        if (!sample.date.isBefore(from)) sample,
    ];
  }

  static double? _rateOver(List<OdometerSample> series, {int minimumDays = 1}) {
    if (series.length < 2) {
      return null;
    }
    final distance = series.last.km - series.first.km;
    final days = series.last.date.difference(series.first.date).inDays;
    if (days < minimumDays || distance <= 0) {
      return null;
    }
    return distance / days;
  }
}
