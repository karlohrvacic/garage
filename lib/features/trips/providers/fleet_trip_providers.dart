import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/trip_entry.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'trip_providers.dart';

/// Fleet-level views of the trip log, kept out of `trip_providers.dart` so
/// that file can be read by anything needing a vehicle's trips — the odometer
/// series, for one — without dragging in the vehicle list it would otherwise
/// have to circle back through.

/// Every trip across the fleet, newest first — what the trip log shows when no
/// single vehicle is picked.
final allTripsProvider = FutureProvider<List<TripEntry>>((ref) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  final perVehicle = await Future.wait([
    for (final vehicle in vehicles)
      ref.watch(tripEntriesProvider(vehicle.id).future),
  ]);
  return [for (final list in perVehicle) ...list]
    ..sort((a, b) => b.date.compareTo(a.date));
});
