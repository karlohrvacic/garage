import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/stations/fuel_station.dart';
import '../data/stations_repository.dart';

final stationsRepositoryProvider = Provider<StationsRepository>((ref) {
  return StationsRepository();
});

/// Every Croatian station with current prices. Kept alive for the session —
/// the upstream dataset only changes a few times a day.
final stationsProvider = FutureProvider<List<FuelStation>>((ref) async {
  return ref.watch(stationsRepositoryProvider).fetchStations();
});

/// The device position, or null when it cannot be had — permission declined,
/// the browser blocks geolocation (Brave does by default), services off, or
/// no fix within the time limit. The stations screen degrades to price order
/// instead of failing, so this never throws.
final positionProvider = FutureProvider<Position?>((ref) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 10),
      ),
    );
  } catch (_) {
    // A stale fix still sorts a nearby list usefully; web has none and
    // throws, which lands in the null fallback below.
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
});

class NearbyStation {
  const NearbyStation({required this.station, required this.distanceKm});

  final FuelStation station;

  /// Null when no device position was available.
  final double? distanceKm;
}

/// All stations, with distances when a position is available. Fuel-type
/// filtering, ordering, and truncation happen in the screen, where the
/// selected fuel is known.
final nearbyStationsProvider = FutureProvider<List<NearbyStation>>((ref) async {
  final stations = await ref.watch(stationsProvider.future);
  final position = await ref.watch(positionProvider.future);

  return [
    for (final station in stations)
      NearbyStation(
        station: station,
        distanceKm: position == null
            ? null
            : haversineKm(
                lat1: position.latitude,
                lng1: position.longitude,
                lat2: station.lat,
                lng2: station.lng,
              ),
      ),
  ];
});

/// National average price series per coarse fuel type.
final priceTrendProvider = FutureProvider<List<TrendPoint>>((ref) async {
  return ref.watch(stationsRepositoryProvider).fetchTrend();
});

const _favouritesKey = 'favourite_stations';

/// Station ids the user starred, persisted locally per device.
final favouriteStationsProvider =
    NotifierProvider<FavouriteStationsController, Set<int>>(
      FavouriteStationsController.new,
    );

class FavouriteStationsController extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_favouritesKey) ?? const [];
    state = {for (final id in stored) int.parse(id)};
  }

  Future<void> toggle(int stationId) async {
    final next = Set<int>.from(state);
    if (!next.remove(stationId)) {
      next.add(stationId);
    }
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favouritesKey, [for (final id in next) '$id']);
  }
}
