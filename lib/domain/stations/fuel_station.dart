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
    this.chainBrand,
  });

  final int id;
  final String name;
  final String? brand;
  final String? address;
  final String? place;
  final double lat;
  final double lng;
  final List<StationPrice> prices;

  /// What the operator's forecourts trade under, when it runs enough of them
  /// to be a chain: "INA", "Petrol", "Shell".
  ///
  /// Worked out by [parseStations], the one place that sees the whole feed.
  /// Null for an independent, and for a station built without the feed,
  /// which is taken for one.
  final String? chainBrand;

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
  ///
  /// That was written for "PM - 00123" and the feed turned out to hold "PM
  /// POREČ, ŽBANDAJ": a real place behind the word for a point of sale, which
  /// is how Petrol files all two hundred of its forecourts, and how Tifon,
  /// Lukoil, Adria Oil and AGS file theirs behind "BP" and "BS". The place is
  /// worth keeping and the opening is not, so it gives way to whose forecourt
  /// it is. The fill-up sheet writes this name into the log, where there is
  /// no operator line underneath to say what "PM" left out.
  String get displayName {
    final own = name.trim();
    if (own.isNotEmpty && _hasWord(own)) {
      return _namingTheSign(own);
    }
    final operator = brand?.trim();
    if (operator == null || operator.isEmpty) {
      // Better a code than a blank row: it is at least an identity, and the
      // address underneath is what places it anyway.
      return own;
    }
    return operator;
  }

  /// What a fill-up here is logged under: the brand, for a chain, and
  /// [displayName] for anyone else, whose name is their brand.
  ///
  /// A driver says "INA", not "Krapina - Frana Galovića", and the log reads
  /// the same whichever INA it was. [displayName] stays the stations screen's
  /// headline, where two INA forecourts a kilometre apart are exactly what it
  /// has to tell apart. Which forecourt a fill-up was at is kept beside the
  /// brand, by [id].
  String get brandName => chainBrand ?? displayName;

  /// [own] with an opening "BP", "BS" or "PM" replaced by the operator's name.
  ///
  /// Those three are common nouns — benzinska postaja, benzinska stanica,
  /// prodajno mjesto — and not any operator's scheme, which is why they can be
  /// listed where decision 124 refused to list codes. Left alone when nobody is
  /// known to run the place, and when the name already says who does: "BP
  /// SANTINI" under Santini d.o.o. needs nothing added.
  String _namingTheSign(String own) {
    final sign = _signName;
    final opening = _forecourtWord.firstMatch(own);
    if (sign == null || opening == null || _mentions(own, sign)) {
      return own;
    }
    return '$sign ${own.substring(opening.end)}';
  }

  /// The operator as a sign would put it: "INA – Industrija nafte d.d." is INA,
  /// and "LUKOIL Croatia d.o.o." is LUKOIL.
  String? get _signName => _signOf(brand);

  static String? _signOf(String? name) {
    final operator = name?.trim();
    if (operator == null || operator.isEmpty) {
      return null;
    }
    final short = operator
        .split(RegExp(r'\s[–-]\s|,'))
        .first
        .replaceAll(_legalForm, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return short.length <= 1 ? null : short;
  }

  /// Whether [own] already carries a word of [sign].
  ///
  /// A short word has to stand alone — "INA" is inside "Slatina" — while a long
  /// one may be run together or apart, because the feed writes GasOil's
  /// forecourts as "GAS OIL".
  static bool _mentions(String own, String sign) {
    final words = _words(own);
    final joined = words.join();
    for (final word in _words(sign)) {
      if (word.length < 3) {
        continue;
      }
      if (word.length < 5 ? words.contains(word) : joined.contains(word)) {
        return true;
      }
    }
    return false;
  }

  static List<String> _words(String value) => [
    for (final match in RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(value.toLowerCase()))
      match.group(0)!,
  ];

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
    // brand, or "PM" did, repeating the brand underneath reads as a rendering
    // bug.
    final sign = _signName;
    if (sign != null && key(displayName).startsWith(key(sign))) {
      return null;
    }
    return key(trimmed) == key(displayName) ? null : trimmed;
  }

  /// Whether a name somebody typed or stored refers to this station.
  ///
  /// Any form counts: what is shown now, what the station's own row says —
  /// which is what older fuel entries were filled in with, back when the code
  /// was the headline — and the brand a fill-up is logged under now. That
  /// last answers for every forecourt of a chain, so a caller after one
  /// station has to ask for it by [id], or refuse an answer that is several.
  bool answersTo(String name) {
    final wanted = name.trim().toLowerCase();
    return wanted == this.name.trim().toLowerCase() ||
        wanted == displayName.trim().toLowerCase() ||
        wanted == brandName.trim().toLowerCase();
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

/// "BP", "BS" or "PM", dotted or not.
const _forecourt = r'(?:B\.?P\.?|B\.?S\.?|P\.?M\.?)';

/// A forecourt word opening a name that goes on.
final _forecourtWord = RegExp('^$_forecourt\\s+(?=\\S)', caseSensitive: false);

/// A forecourt word and nothing else.
final _onlyForecourtWord = RegExp('^$_forecourt\$', caseSensitive: false);

/// An operator with at least this many forecourts in the feed is a chain.
/// Below it, the name is what a driver knows the place by.
const _chainSize = 3;

/// What each chain in the feed trades under, by operator id.
///
/// The operator's name as its sign puts it, with a forecourt word it opens
/// with dropped: "B.P. Jozinović" is Jozinović. Unless the operator is not
/// the sign. Coral Croatia runs Shell's forecourts and files every one of
/// them as "Shell …", so a word that every one of a chain's names opens with
/// is the brand — provided it is no forecourt word, which Petrol's "PM" is,
/// and the operator's own name does not carry it, which Mikol's does.
///
/// Every row counts, a station with no coordinates included: the chain is no
/// smaller for one the stations screen cannot place.
Map<int, String> _chainBrands(
  List<Map<String, dynamic>> rows,
  Map<int, String> operators,
) {
  final names = <int, List<String>>{};
  for (final row in rows) {
    if (row['obveznik_id'] case final int operator) {
      (names[operator] ??= []).add((row['naziv'] as String? ?? '').trim());
    }
  }
  return {
    for (final MapEntry(key: operator, value: stations) in names.entries)
      if (stations.length >= _chainSize)
        operator: ?_brandOf(stations, operators[operator]),
  };
}

String? _brandOf(List<String> stations, String? operator) {
  final opening = _sharedOpening(stations);
  if (opening != null &&
      _hasWord(opening) &&
      !_onlyForecourtWord.hasMatch(opening) &&
      !(operator != null && FuelStation._mentions(operator, opening))) {
    return opening;
  }
  final sign = FuelStation._signOf(operator);
  if (sign == null) {
    return null;
  }
  final forecourt = _forecourtWord.firstMatch(sign);
  return forecourt == null ? sign : sign.substring(forecourt.end);
}

/// The word every one of [names] opens with, spelled as the first of them
/// spells it and without punctuation after it, or null when they do not all
/// open with the same one.
String? _sharedOpening(List<String> names) {
  String? shared;
  for (final name in names) {
    final word = name
        .split(RegExp(r'\s+'))
        .first
        .replaceFirst(RegExp(r'[^\p{L}\p{N}]+$', unicode: true), '');
    if (word.isEmpty) {
      return null;
    }
    if (shared == null) {
      shared = word;
    } else if (word.toLowerCase() != shared.toLowerCase()) {
      return null;
    }
  }
  return shared;
}

/// What a company is in law, and where it trades, neither of which is on the
/// sign.
final _legalForm = RegExp(
  r'\b(?:j\.?\s?d\.?\s?o\.?\s?o|d\.?\s?o\.?\s?o|d\.?\s?d|croatia|hrvatska)\b\.?',
  caseSensitive: false,
);

/// The station a fill-up kept the dataset's id of, or null when that id is not
/// to be trusted.
///
/// The id was kept beside the station text the sheet wrote, and describes
/// that text and nothing else. It is trusted while the feed still carries the
/// station and the station still answers to [stationName]: a build that
/// predates the id can change the text and leave the id behind, and the text
/// is what the household last said.
FuelStation? recognisedStation({
  required List<FuelStation> stations,
  required int? stationRef,
  required String stationName,
}) {
  if (stationRef == null) {
    return null;
  }
  for (final station in stations) {
    if (station.id == stationRef) {
      return station.answersTo(stationName) ? station : null;
    }
  }
  return null;
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

  final rows = [
    for (final row in (json['postajas'] as List<dynamic>? ?? const []))
      row as Map<String, dynamic>,
  ];
  final chains = _chainBrands(rows, brands);

  final stations = <FuelStation>[];
  for (final map in rows) {
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
        chainBrand: chains[map['obveznik_id']],
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
