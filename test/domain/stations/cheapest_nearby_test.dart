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
}
