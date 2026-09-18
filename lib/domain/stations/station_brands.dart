import 'fuel_station.dart';

/// What each forecourt in the feed is logged under today, looked up by any
/// name an older fill-up may have saved it under.
///
/// A fill-up saved before decision 161 kept the feed's own name, "PM POREČ,
/// ŽBANDAJ". One saved while 161 stood kept the name the sign gave it,
/// "Petrol POREČ, ŽBANDAJ". One saved since 170 keeps the brand, "Petrol".
/// Nothing rewrites the old ones, so whatever groups fill-ups by station asks
/// this which station a saved name was.
class StationBrands {
  StationBrands(Iterable<FuelStation> stations) : _byName = _index(stations);

  const StationBrands._none() : _byName = const {};

  /// For when the feed is not to hand: every name is its own station, which
  /// is how the statistics read before this existed.
  static const none = StationBrands._none();

  final Map<String, String> _byName;

  /// The brand [saved] is logged under today, or [saved] itself when the feed
  /// does not know the name, or knows it as two brands' forecourts.
  String of(String saved) => _byName[_key(saved)] ?? saved;

  static String _key(String name) => name.trim().toLowerCase();

  static Map<String, String> _index(Iterable<FuelStation> stations) {
    final byName = <String, String>{};
    final shared = <String>{};
    for (final station in stations) {
      final brand = station.brandName;
      for (final name in {station.name, station.displayName}) {
        final key = _key(name);
        if (key.isEmpty || shared.contains(key)) {
          continue;
        }
        final known = byName[key];
        if (known == null) {
          byName[key] = brand;
        } else if (known != brand) {
          // "BP ZAGREB" under two operators is no answer to which one a
          // fill-up was at.
          byName.remove(key);
          shared.add(key);
        }
      }
    }
    return byName;
  }
}
