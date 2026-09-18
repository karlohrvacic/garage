import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/stations/station_at_the_pump.dart';
import '../../stations/providers/station_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// The station this vehicle is standing at, if it is standing at one.
///
/// Everything needed already exists: the app holds every Croatian station's
/// position and today's posted prices, and the driver's own position when they
/// have granted it. Someone at a pump typing what they just paid is typing a
/// number the app could have offered.
///
/// Null whenever anything is missing — no permission, no fix, too far from a
/// station, or a car that does not take a fuel the dataset prices. Every one of
/// those is silent: the sheet simply behaves as it did before.
/// Which fill-up a pump match is for: the car, and the fuel going in, or null
/// for the car's own.
typedef PumpQuery = ({String vehicleId, String? fuelTypeKey});

final stationAtThePumpProvider = FutureProvider.family<PumpMatch?, PumpQuery>((
  ref,
  query,
) async {
  final position = await ref.watch(grantedPositionProvider.future);
  if (position == null) {
    return null;
  }

  final vehicle = await ref.watch(vehicleProvider(query.vehicleId).future);
  if (vehicle == null) {
    return null;
  }
  // The fuel going in, where the dataset prices it: a petrol car on
  // autogas filling LPG is at the nearest forecourt selling LPG, which
  // may sell nothing else, and filling petrol it is not at a nearer one
  // that sells only LPG. A charge has no posted price, so the forecourt
  // is the one the car's own fuel finds, as it always was.
  final fuelTypeId =
      StationFuel.forVehicle(query.fuelTypeKey ?? vehicle.fuelTypeKey) ??
      StationFuel.forVehicle(vehicle.fuelTypeKey);
  if (fuelTypeId == null) {
    return null;
  }

  final nearby = await ref.watch(nearbyStationsProvider.future);
  return StationAtThePump.match(
    nearby: [
      for (final entry in nearby)
        (station: entry.station, distanceKm: entry.distanceKm),
    ],
    fuelTypeId: fuelTypeId,
  );
});
