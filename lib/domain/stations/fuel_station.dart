import 'dart:math' as math;

/// A fuel type's price at one station, resolved to a display name and its
/// coarse type (petrol / diesel / LPG / other) from the MZOE dataset.
class StationPrice {
  const StationPrice({
    required this.fuelName,
    required this.fuelTypeId,
    required this.price,
  });

  final String fuelName;

  /// MZOE `tip_goriva` id: 1 petrol, 2 diesel, 3 LPG; anything else "other".
  final int fuelTypeId;

  final double price;
}

class FuelStation {
  const FuelStation({
    required this.id,
    required this.name,
    required this.brand,
    required this.address,
    required this.place,
    required this.lat,
    required this.lng,
    required this.prices,
  });

  final int id;
  final String name;
  final String? brand;
  final String? address;
  final String? place;
  final double lat;
  final double lng;
  final List<StationPrice> prices;

  /// Cheapest price for a coarse fuel type, or null when the station does not
  /// sell it.
  double? cheapestFor(int fuelTypeId) {
    double? cheapest;
    for (final price in prices) {
      if (price.fuelTypeId == fuelTypeId &&
          (cheapest == null || price.price < cheapest)) {
        cheapest = price.price;
      }
    }
    return cheapest;
  }
}

/// Parses the MZOE `data.gz` payload (already gunzipped and JSON-decoded)
/// into stations with resolved brand names and fuel labels. Stations without
/// coordinates are dropped — they cannot be placed in a nearby list.
List<FuelStation> parseStations(Map<String, dynamic> json) {
  final brands = <int, String>{
    for (final row in (json['obvezniks'] as List<dynamic>? ?? const []))
      (row as Map<String, dynamic>)['id'] as int: row['naziv'] as String? ?? '',
  };
  final fuelTypeByVrsta = <int, int>{
    for (final row in (json['vrsta_gorivas'] as List<dynamic>? ?? const []))
      (row as Map<String, dynamic>)['id'] as int:
          row['tip_goriva_id'] as int? ?? 0,
  };
  final fuels = <int, ({String name, int typeId})>{
    for (final row in (json['gorivos'] as List<dynamic>? ?? const []))
      (row as Map<String, dynamic>)['id'] as int: (
        name: row['naziv'] as String? ?? '',
        typeId: fuelTypeByVrsta[row['vrsta_goriva_id']] ?? 0,
      ),
  };

  final stations = <FuelStation>[];
  for (final row in (json['postajas'] as List<dynamic>? ?? const [])) {
    final map = row as Map<String, dynamic>;
    // The dataset swaps the fields: `long` holds latitude and `lat` holds
    // longitude (Croatia sits at ~45°N, ~16°E).
    final lat = double.tryParse(map['long'] as String? ?? '');
    final lng = double.tryParse(map['lat'] as String? ?? '');
    if (lat == null || lng == null) {
      continue;
    }
    final prices = <StationPrice>[];
    for (final entry in (map['cjenici'] as List<dynamic>? ?? const [])) {
      final priceRow = entry as Map<String, dynamic>;
      final fuel = fuels[priceRow['gorivo_id']];
      final price = (priceRow['cijena'] as num?)?.toDouble();
      // Zero means "not selling this right now", not "free". The feed uses it
      // for a pump that is out or a fuel a station has stopped carrying, and
      // read as a real price it wins every comparison there is: the app
      // announced such a station as the cheapest around, at 0.00 €, in the
      // largest text on the screen. Dropped here rather than in `cheapestFor`
      // so it cannot reach the station's own price list either.
      if (fuel == null || price == null || price <= 0) {
        continue;
      }
      prices.add(
        StationPrice(
          fuelName: fuel.name,
          fuelTypeId: fuel.typeId,
          price: price,
        ),
      );
    }
    stations.add(
      FuelStation(
        id: map['id'] as int,
        name: map['naziv'] as String? ?? '',
        brand: brands[map['obveznik_id']],
        address: map['adresa'] as String?,
        place: map['mjesto'] as String?,
        lat: lat,
        lng: lng,
        prices: prices,
      ),
    );
  }
  return stations;
}

/// Great-circle distance in kilometres.
double haversineKm({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const earthRadiusKm = 6371.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLng = radians(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(a.toDouble()));
}
