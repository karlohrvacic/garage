import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/cheapest_nearby.dart';
import 'package:garage/domain/stations/fuel_station.dart';

/// Roughly one kilometre of latitude, for placing stations a known way apart.
const _kmInDegrees = 1 / 111.0;

FuelStation at(
  String name, {
  required double price,
  double kmNorth = 0,
  int fuelTypeId = 2,
}) {
  return FuelStation(
    id: name.hashCode ^ kmNorth.hashCode,
    name: name,
    brand: null,
    address: null,
    place: null,
    lat: 45.8 + kmNorth * _kmInDegrees,
    lng: 15.98,
    prices: [
      StationPrice(fuelName: 'eurodizel', fuelTypeId: fuelTypeId, price: price),
    ],
  );
}

CheapestNearby? cheapest(
  List<FuelStation> stations, {
  String? name = 'INA Vukovarska',
  int? fuelTypeId = 2,
  double radiusKm = 5,
}) {
  return cheapestNear(
    stations: stations,
    stationName: name,
    fuelTypeId: fuelTypeId,
    radiusKm: radiusKm,
  );
}

void main() {
  group('what else was on offer nearby', () {
    test('finds a cheaper station within the radius', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        at('Petrol Ilica', price: 1.54, kmNorth: 3),
      ]);

      expect(result!.pricePerUnit, 1.54);
      expect(result.station, 'Petrol Ilica');
      expect(result.distanceKm, closeTo(3, 0.1));
    });

    test('the station you used can be the cheapest one', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.54),
        at('Petrol Ilica', price: 1.66, kmNorth: 3),
      ]);

      expect(result!.station, 'INA Vukovarska');
      expect(result.distanceKm, closeTo(0, 0.01));
    });

    test('ignores a cheaper station beyond the radius', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        at('Far Away', price: 1.20, kmNorth: 20),
      ]);

      expect(
        result!.station,
        'INA Vukovarska',
        reason: 'a 40 km round trip is not an alternative to the pump you used',
      );
    });

    test('ignores a station that does not sell that fuel', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        at('LPG Only', price: 0.70, kmNorth: 1, fuelTypeId: 3),
      ]);

      expect(result!.pricePerUnit, 1.66);
    });

    test('matches the anchor name regardless of case and spacing', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        at('Petrol Ilica', price: 1.54, kmNorth: 2),
      ], name: '  ina vukovarska  ');

      expect(result!.pricePerUnit, 1.54);
    });
  });

  group('when it will not answer', () {
    test('no station name was recorded on the fill-up', () {
      expect(cheapest([at('INA Vukovarska', price: 1.66)], name: null), isNull);
      expect(cheapest([at('INA Vukovarska', price: 1.66)], name: ' '), isNull);
    });

    test('the station is not one the dataset carries', () {
      expect(
        cheapest([at('INA Vukovarska', price: 1.66)], name: 'Some Yard'),
        isNull,
      );
    });

    test('a car the dataset does not price', () {
      expect(
        cheapest([at('INA Vukovarska', price: 1.66)], fuelTypeId: null),
        isNull,
      );
    });

    // A chain repeats its name across forecourts. Two anchors means two
    // neighbourhoods, and picking one would be a coin toss recorded as a fact.
    test('the name belongs to two forecourts far apart', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        at('INA Vukovarska', price: 1.60, kmNorth: 50),
        at('Petrol Ilica', price: 1.54, kmNorth: 2),
      ]);

      expect(result, isNull);
    });

    test('two forecourts of one name on the same spot are not ambiguous', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        at('INA Vukovarska', price: 1.66),
        at('Petrol Ilica', price: 1.54, kmNorth: 2),
      ]);

      expect(result!.pricePerUnit, 1.54);
    });

    test('the anchor sells the fuel but nothing priced is in range', () {
      expect(
        cheapest([at('INA Vukovarska', price: 1.66, fuelTypeId: 3)]),
        isNull,
      );
    });
  });

  // The fill-up sheet now logs the brand, which a chain shares across every
  // forecourt it runs, and keeps the dataset's id for the one it recognised.
  group('the forecourt the fill-up was at', () {
    FuelStation petrol(int id, String place, double price, {double km = 0}) {
      return FuelStation(
        id: id,
        name: 'PM $place',
        brand: 'Petrol d.o.o.',
        address: null,
        place: place,
        lat: 45.8 + km * _kmInDegrees,
        lng: 15.98,
        chainBrand: 'Petrol',
        prices: [
          StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: price),
        ],
      );
    }

    test('anchors the comparison where the brand alone cannot', () {
      final stations = [
        petrol(1, 'LUČKO', 1.66),
        at('Tifon Lučko', price: 1.54, kmNorth: 3),
        petrol(2, 'KARLOVAC', 1.40, km: 50),
      ];

      expect(
        cheapestNear(stations: stations, stationName: 'Petrol', fuelTypeId: 2),
        isNull,
        reason: 'two forecourts of the brand, fifty kilometres apart',
      );
      final result = cheapestNear(
        stations: stations,
        stationName: 'Petrol',
        stationRef: 1,
        fuelTypeId: 2,
      )!;
      expect(result.station, 'Tifon Lučko');
      expect(result.pricePerUnit, 1.54);
      expect(result.distanceKm, closeTo(3, 0.1));
    });

    test('names the cheapest by the brand a fill-up is logged under', () {
      final result = cheapest([
        at('INA Vukovarska', price: 1.66),
        petrol(3, 'ILICA', 1.50, km: 2),
      ])!;

      expect(result.station, 'Petrol');
    });

    test('is not trusted once the station kept with it says otherwise', () {
      final result = cheapestNear(
        stations: [
          petrol(1, 'LUČKO', 1.50),
          at('Tifon Lučko', price: 1.60, kmNorth: 20),
        ],
        stationName: 'Tifon Lučko',
        stationRef: 1,
        fuelTypeId: 2,
      )!;

      expect(result.station, 'Tifon Lučko');
      expect(result.distanceKm, closeTo(0, 0.01));
    });

    test('falls back to the name when the feed no longer carries it', () {
      final result = cheapestNear(
        stations: [
          at('INA Vukovarska', price: 1.66),
          at('Petrol Ilica', price: 1.54, kmNorth: 3),
        ],
        stationName: 'INA Vukovarska',
        stationRef: 99,
        fuelTypeId: 2,
      )!;

      expect(result.station, 'Petrol Ilica');
    });
  });
}
