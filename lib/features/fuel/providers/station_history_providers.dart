import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/fuel/station_history.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'fuel_providers.dart';

/// Every station the household has ever logged, most-used first — the options
/// behind the station picker on a fill-up.
///
/// Fleet-wide rather than per-vehicle: people fuel whatever they are driving
/// at the same handful of stations, and archived vehicles keep contributing
/// their history. The per-vehicle logs this reads are the same ones the
/// dashboard already holds, so in practice it costs no extra round trip.
final knownStationsProvider = FutureProvider<List<String>>((ref) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  final perVehicle = await Future.wait([
    for (final vehicle in vehicles)
      ref.watch(rawFuelEntriesProvider(vehicle.id).future),
  ]);
  return StationHistory.rank([for (final entries in perVehicle) ...entries]);
});
