import 'fuel_station.dart';

/// A station and how far away it is. Structurally what `NearbyStation` carries,
/// as a record so this stays in the domain layer with no dependency on the
/// feature that fetches them.
typedef StationDistance = ({FuelStation station, double? distanceKm});

/// A station the driver is close enough to be standing at, with the price it
/// charges for their fuel.
class PumpMatch {
  const PumpMatch({
    required this.station,
    required this.pricePerUnit,
    required this.distanceKm,
  });

  final FuelStation station;
  final double pricePerUnit;
  final double distanceKm;
}

/// Which of the ministry's priced fuels a vehicle takes.
abstract final class StationFuel {
  /// Null for anything the dataset does not price — an electric car does not
  /// fill up at a pump with a posted price, and guessing petrol for it would
  /// put a made-up number on the entry.
  static int? forVehicle(String fuelTypeKey) {
    return switch (fuelTypeKey) {
      'fuel_petrol' => 1,
      'fuel_diesel' => 2,
      'fuel_lpg' => 3,
      _ => null,
    };
  }
}

/// Works out which station a fill-up is being logged at.
///
/// The app already holds every Croatian station's position and today's posted
/// prices, and asks for a position on the stations screen. Someone standing at
/// a pump typing what they just paid is therefore typing something the app
/// could have offered — so it offers it, as a starting value they can change,
/// never as a value they cannot.
abstract final class StationAtThePump {
  /// How close counts as "at this station".
  ///
  /// A forecourt is tens of metres across and a phone's fix is usually good to
  /// within that. Two hundred metres is generous enough to survive a poor fix
  /// under a canopy and tight enough that the station across the junction, with
  /// a different price, is not offered as though it were this one.
  static const double atThePumpKm = 0.2;

  static PumpMatch? match({
    required List<StationDistance> nearby,
    required int? fuelTypeId,
  }) {
    if (fuelTypeId == null) {
      return null;
    }

    PumpMatch? best;
    for (final entry in nearby) {
      final distance = entry.distanceKm;
      if (distance == null || distance > atThePumpKm) {
        continue;
      }
      final price = entry.station.cheapestFor(fuelTypeId);
      if (price == null) {
        // Close, but does not sell what this car takes.
        continue;
      }
      if (best == null || distance < best.distanceKm) {
        best = PumpMatch(
          station: entry.station,
          pricePerUnit: price,
          distanceKm: distance,
        );
      }
    }
    return best;
  }
}
