import '../entities/fuel_entry.dart';

/// The stations a household has actually fuelled at, ranked for a picker.
///
/// Most-used first: refuelling is habitual, so the two or three regulars
/// belong at the top of the list no matter how long the tail behind them is.
/// Recency breaks ties, which is what surfaces a newly adopted station over an
/// equally-used one abandoned last year.
abstract final class StationHistory {
  static List<String> rank(List<FuelEntry> entries) {
    final tallies = <String, _Tally>{};

    for (final entry in entries) {
      final name = entry.station?.trim();
      if (name == null || name.isEmpty) {
        continue;
      }
      // Case-folded key, so "INA" and "Ina" are one station rather than two
      // near-identical options the user has to choose between.
      final tally = tallies[name.toLowerCase()];
      if (tally == null) {
        tallies[name.toLowerCase()] = _Tally(name: name, lastUsed: entry.date);
      } else {
        tally.count++;
        if (entry.date.isAfter(tally.lastUsed)) {
          // The spelling shown is the one typed most recently.
          tally.lastUsed = entry.date;
          tally.name = name;
        }
      }
    }

    final ranked = tallies.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) {
          return byCount;
        }
        final byRecency = b.lastUsed.compareTo(a.lastUsed);
        if (byRecency != 0) {
          return byRecency;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return [for (final tally in ranked) tally.name];
  }

  /// The options worth offering for [query] — a plain contains-match, so
  /// typing "ina" finds both "INA" and "Petrolina".
  static List<String> matching(List<String> stations, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return stations;
    }
    return [
      for (final station in stations)
        if (station.toLowerCase().contains(needle)) station,
    ];
  }
}

class _Tally {
  _Tally({required this.name, required this.lastUsed});

  String name;
  DateTime lastUsed;
  int count = 1;
}
