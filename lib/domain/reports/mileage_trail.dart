import '../fuel/odometer_history.dart';

/// One year of a car's recorded mileage, for the report a buyer reads.
class MileageYear {
  const MileageYear({
    required this.year,
    required this.endKm,
    required this.records,
    this.km,
    this.partial = false,
    this.sinceLastReading = false,
  });

  final int year;

  /// The last reading recorded in this year. What the odometer said, not a
  /// figure derived from anything.
  final int endKm;

  /// How many readings the year rests on. A year backed by one reading and a
  /// year backed by forty should not look the same to a buyer.
  final int records;

  /// Kilometres between the previous known reading and [endKm], or null when
  /// there is nothing before it to measure from.
  final int? km;

  /// Whether the records begin part-way through this year, so [km] covers less
  /// than the year does.
  final bool partial;

  /// Whether [km] spans a gap — the last reading before it is from an earlier
  /// year than the one just gone.
  final bool sinceLastReading;
}

/// The years a car has records for, oldest first.
///
/// **Years with no readings are left out rather than shown as zero.** A car
/// nobody logged for a year did not stand still; saying so on a document
/// somebody is buying from would be an invention.
List<MileageYear> mileageTrail(List<OdometerSample> samples) {
  if (samples.isEmpty) {
    return const [];
  }
  final sorted = [...samples]..sort((a, b) => a.date.compareTo(b.date));

  final byYear = <int, List<OdometerSample>>{};
  for (final sample in sorted) {
    byYear.putIfAbsent(sample.date.year, () => <OdometerSample>[]).add(sample);
  }

  final years = byYear.keys.toList()..sort();
  final trail = <MileageYear>[];
  OdometerSample? previous;

  for (final year in years) {
    final inYear = byYear[year]!;
    final last = inYear.last;
    // Measured from the last reading before this year where there is one, so
    // the distance driven over a New Year is not lost; from this year's own
    // first reading otherwise.
    final from = previous ?? (inYear.length > 1 ? inYear.first : null);
    trail.add(
      MileageYear(
        year: year,
        endKm: last.km,
        records: inYear.length,
        km: from == null ? null : last.km - from.km,
        partial: previous == null,
        sinceLastReading: previous != null && previous.date.year < year - 1,
      ),
    );
    previous = last;
  }
  return trail;
}
