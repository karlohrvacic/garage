import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/posted_price.dart';

FuelStation station(
  String name, {
  List<({int typeId, double price})> prices = const [],
}) {
  return FuelStation(
    id: name.hashCode,
    name: name,
    brand: null,
    address: null,
    place: null,
    lat: 45.8,
    lng: 16,
    prices: [
      for (final price in prices)
        StationPrice(
          fuelName: 'fuel',
          fuelTypeId: price.typeId,
          price: price.price,
        ),
    ],
  );
}

final ina = station(
  'INA Vukovarska',
  prices: [(typeId: 1, price: 1.49), (typeId: 2, price: 1.66)],
);

void main() {
  group("today's price where you filled up last time", () {
    test('is the posted price for the fuel that car takes', () {
      expect(
        postedPriceAt(
          stations: [ina],
          stationName: 'INA Vukovarska',
          fuelTypeId: 2,
        ),
        1.66,
      );
    });

    test('ignores the case and the spaces around a remembered name', () {
      expect(
        postedPriceAt(
          stations: [ina],
          stationName: '  ina vukovarska ',
          fuelTypeId: 2,
        ),
        1.66,
      );
    });

    test('is nothing when that station does not sell the fuel', () {
      expect(
        postedPriceAt(
          stations: [ina],
          stationName: 'INA Vukovarska',
          fuelTypeId: 3,
        ),
        isNull,
      );
    });

    test('is nothing for a station that is not in the dataset', () {
      expect(
        postedPriceAt(stations: [ina], stationName: 'Some Yard', fuelTypeId: 2),
        isNull,
      );
    });

    test('is nothing without a station to look up', () {
      expect(
        postedPriceAt(stations: [ina], stationName: null, fuelTypeId: 2),
        isNull,
      );
      expect(
        postedPriceAt(stations: [ina], stationName: '  ', fuelTypeId: 2),
        isNull,
      );
    });

    test('is nothing for a car the dataset does not price', () {
      expect(
        postedPriceAt(
          stations: [ina],
          stationName: 'INA Vukovarska',
          fuelTypeId: null,
        ),
        isNull,
      );
    });

    test(
      'refuses to guess between two stations of that name that disagree',
      () {
        final other = station(
          'INA Vukovarska',
          prices: [(typeId: 2, price: 1.71)],
        );

        expect(
          postedPriceAt(
            stations: [ina, other],
            stationName: 'INA Vukovarska',
            fuelTypeId: 2,
          ),
          isNull,
          reason:
              'two forecourts, two prices, and no way to tell which was meant',
        );
      },
    );

    test(
      'two stations of that name charging the same is not a disagreement',
      () {
        final twin = station(
          'INA Vukovarska',
          prices: [(typeId: 2, price: 1.66)],
        );

        expect(
          postedPriceAt(
            stations: [ina, twin],
            stationName: 'INA Vukovarska',
            fuelTypeId: 2,
          ),
          1.66,
        );
      },
    );
  });
}
