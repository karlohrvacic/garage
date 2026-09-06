import 'dart:math' as math;
import 'station_at_the_pump.dart';

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
  /// Below this a "price" is a data-entry artefact, not a pump price: the
  /// open data has carried figures like 0.67 for a litre of diesel, and the
  /// screen promoted the lowest number it could find to its headline.
  ///
  /// Per fuel, because autogas is genuinely cheap: a flat floor set for
  /// petrol and diesel would have hidden real LPG prices, which is the same
  /// mistake in the other direction.
  static double floorFor(int fuelTypeId) =>
      fuelTypeId == StationFuel.lpg ? 0.35 : 0.80;

  /// The name to put in front of a driver.
  ///
  /// Normally the station's own [name]: two INA forecourts a kilometre apart
  /// are exactly what it tells apart. But some operators file a forecourt
  /// under an internal sales-point code — Petrol's rows read "PM - 00123" —
  /// and a code is not a name. When the station's own name contains no word
  /// at all, the brand is what the sign says and the code is not.
  ///
  /// A word is three letters together. "PM" and "1042" are not words; "Tif 4"
  /// is somebody's forecourt.
  String get displayName {
    final own = name.trim();
    if (own.isNotEmpty && _hasWord(own)) {
      return own;
    }
    final operator = brand?.trim();
    if (operator == null || operator.isEmpty) {
      // Better a code than a blank row: it is at least an identity, and the
      // address underneath is what places it anyway.
      return own;
    }
    return operator;
  }

  /// The operator worth showing beside the station's own name, or null when
  /// it adds nothing.
  ///
  /// The dataset carries single-letter brands, and brands that differ from
  /// the station name only in spacing or case — "N.B.NENA d.o.o." over
  /// "N.B. Nena d.o.o." rendered as two lines that read like a bug.
  String? get operatorName {
    final trimmed = brand?.trim();
    if (trimmed == null || trimmed.length <= 1) {
      return null;
    }
    String key(String value) =>
        value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    // Against the headline, not the raw name: where a code gave way to the
    // brand, repeating the brand underneath reads as a rendering bug.
    return key(trimmed) == key(displayName) ? null : trimmed;
  }

  /// Whether a name somebody typed or stored refers to this station.
  ///
  /// Either form counts: what is shown now, and what the station's own row
  /// says — which is what older fuel entries were filled in with, back when
  /// the code was the headline.
  bool answersTo(String name) {
    final wanted = name.trim().toLowerCase();
    return wanted == this.name.trim().toLowerCase() ||
        wanted == displayName.trim().toLowerCase();
  }

  double? cheapestFor(int fuelTypeId) {
    final floor = floorFor(fuelTypeId);
    double? cheapest;
    for (final price in prices) {
      if (price.fuelTypeId == fuelTypeId &&
          price.price >= floor &&
          (cheapest == null || price.price < cheapest)) {
        cheapest = price.price;
      }
    }
    return cheapest;
  }
}

/// Whether a string contains a word — three letters in a row — as opposed to
/// an identifier like "PM - 00123" or "1042".
///
/// Deliberately not a pattern for the codes seen so far: a rule that lists
/// "PM" learns nothing about the next operator's scheme, while "has a word in
/// it" is the property that actually separates a name from a reference.
bool _hasWord(String value) =>
    RegExp(r'[\p{L}]{3}', unicode: true).hasMatch(value);

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
