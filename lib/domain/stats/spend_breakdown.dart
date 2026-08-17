/// One wedge of a spend breakdown: what it was, and how much.
class SpendSlice {
  const SpendSlice({
    required this.label,
    required this.amount,
    this.isOthers = false,
  });

  /// The name this spend was under — a station, a category, a service type.
  /// Null when there is no name: entries that recorded no station, or the
  /// rolled-up tail of a long list.
  final String? label;

  final double amount;

  /// Whether this slice is the rolled-up tail rather than one real thing. The
  /// presentation layer needs to know, because "Others" and "not recorded"
  /// read the same in a legend and mean different things.
  final bool isOthers;

  @override
  bool operator ==(Object other) =>
      other is SpendSlice &&
      other.label == label &&
      other.amount == amount &&
      other.isOthers == isOthers;

  @override
  int get hashCode => Object.hash(label, amount, isOthers);

  @override
  String toString() =>
      'SpendSlice(label: $label, amount: $amount, isOthers: $isOthers)';
}

/// Turns a list of labelled amounts into the slices a donut can draw.
abstract final class SpendBreakdown {
  /// Sums by label, biggest first, dropping anything that came to nothing.
  ///
  /// An empty label and a missing one are the same thing — a fill-up where
  /// nobody typed the station — and are grouped under a null label rather than
  /// appearing as a slice named "".
  static List<SpendSlice> group(Iterable<(String?, double)> amounts) {
    final totals = <String?, double>{};
    for (final (label, amount) in amounts) {
      final key = (label == null || label.trim().isEmpty) ? null : label.trim();
      totals[key] = (totals[key] ?? 0) + amount;
    }

    final slices = [
      for (final entry in totals.entries)
        if (entry.value > 0) SpendSlice(label: entry.key, amount: entry.value),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  /// Keeps the first [limit] slices and rolls the rest into one.
  ///
  /// Expects [slices] already ordered biggest first; this trims a list, it
  /// does not sort one. A tail of exactly one is left alone: an "Others" that
  /// is a single named thing hides a name and gains nothing.
  static List<SpendSlice> topN(List<SpendSlice> slices, int limit) {
    if (slices.length <= limit + 1) {
      return slices;
    }
    final tail = slices.skip(limit);
    return [
      ...slices.take(limit),
      SpendSlice(
        label: null,
        amount: tail.fold<double>(0, (sum, slice) => sum + slice.amount),
        isOthers: true,
      ),
    ];
  }
}
