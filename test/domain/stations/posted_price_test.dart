import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
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

  group('a station filed under a code', () {
    final petrol = FuelStation(
      id: 9,
      name: 'PM - 00123',
      brand: 'PETROL d.o.o.',
      address: 'Zagrebačka 1',
      place: 'Velika Gorica',
      lat: 45.7,
      lng: 16.07,
      prices: const [
        StationPrice(fuelName: 'Eurodiesel', fuelTypeId: 2, price: 1.55),
      ],
    );

    test('answers to the brand a driver now sees', () {
      expect(
        postedPriceAt(
          stations: [petrol],
          stationName: 'PETROL d.o.o.',
          fuelTypeId: 2,
        ),
        1.55,
      );
    });

    test('still answers to the code older entries were saved with', () {
      // Fuel entries typed before the headline changed carry "PM - 00123".
      // Dropping that match would quietly stop showing them a posted price.
      expect(
        postedPriceAt(
          stations: [petrol],
          stationName: 'PM - 00123',
          fuelTypeId: 2,
        ),
        1.55,
      );
    });
  });

  // The fill-up sheet now logs the brand, which a chain shares across every
  // forecourt it runs, and keeps the dataset's id for the one it recognised.
  group('the forecourt the last fill-up was at', () {
    FuelStation forecourt(
      int id,
      String name, {
      required String chain,
      required double diesel,
      double? petrol,
    }) {
      return FuelStation(
        id: id,
        name: name,
        brand: '$chain d.o.o.',
        address: null,
        place: null,
        lat: 45.8,
        lng: 16,
        chainBrand: chain,
        prices: [
          StationPrice(fuelName: 'Eurodiesel', fuelTypeId: 2, price: diesel),
          if (petrol != null)
            StationPrice(
              fuelName: 'Eurosuper 95',
              fuelTypeId: 1,
              price: petrol,
            ),
        ],
      );
    }

    final rovinj = forecourt(11, 'PM ROVINJ', chain: 'Petrol', diesel: 1.55);
    final zadar = forecourt(12, 'PM ZADAR', chain: 'Petrol', diesel: 1.61);
    final lucko = forecourt(21, 'BP LUČKO', chain: 'Tifon', diesel: 1.49);

    test('is priced exactly where the brand alone is not an answer', () {
      expect(
        postedPriceAt(
          stations: [rovinj, zadar],
          stationName: 'Petrol',
          fuelTypeId: 2,
        ),
        isNull,
        reason: 'two forecourts of the brand, two prices',
      );
      expect(
        postedPriceAt(
          stations: [rovinj, zadar],
          stationName: 'Petrol',
          stationRefs: const [12],
          fuelTypeId: 2,
        ),
        1.61,
      );
    });

    test('a chain charging one price everywhere answers to its brand', () {
      final pula = forecourt(13, 'PM PULA', chain: 'Petrol', diesel: 1.55);

      expect(
        postedPriceAt(
          stations: [rovinj, pula],
          stationName: 'Petrol',
          fuelTypeId: 2,
        ),
        1.55,
      );
    });

    test('is not trusted once the station kept with it says otherwise', () {
      // A build that predates the id can rename a fill-up's station and leave
      // the id behind. The name is what the household last said.
      expect(
        postedPriceAt(
          stations: [rovinj, zadar, lucko],
          stationName: 'Tifon',
          stationRefs: const [12],
          fuelTypeId: 2,
        ),
        1.49,
      );
    });

    test('asks the newest forecourt that still answers to the name', () {
      // Newest first. Lučko is a Tifon, so an id that points at it beside the
      // name "Petrol" is stale and the next one is asked.
      expect(
        postedPriceAt(
          stations: [rovinj, zadar, lucko],
          stationName: 'Petrol',
          stationRefs: const [21, 12, 11],
          fuelTypeId: 2,
        ),
        1.61,
      );
    });

    test('falls back to the name when the feed no longer carries it', () {
      expect(
        postedPriceAt(
          stations: [rovinj, lucko],
          stationName: 'Petrol',
          stationRefs: const [99],
          fuelTypeId: 2,
        ),
        1.55,
      );
    });

    group('which forecourts earlier fill-ups kept', () {
      FuelEntry logged(String id, String? station, {int? ref}) => FuelEntry(
        id: id,
        vehicleId: 'v1',
        date: DateTime.utc(2026, 7, 1),
        odometerKm: 50000,
        volumeL: 40,
        fullTank: true,
        missedFill: false,
        station: station,
        stationRef: ref,
        createdBy: 'u1',
      );

      test('are those logged under the same name, newest first', () {
        // The log is oldest first. A fill-up logged at home under "INA" kept
        // no id, and one logged under another name lends its id to nothing.
        final history = [
          logged('f1', 'INA', ref: 1300),
          logged('f2', 'Petrol', ref: 11),
          logged('f3', ' ina ', ref: 1400),
          logged('f4', 'INA'),
          logged('f5', null, ref: 1500),
        ];

        expect(recognisedForecourts(history, 'INA'), [1400, 1300]);
      });

      test('are none when no fill-up under that name was recognised', () {
        expect(recognisedForecourts([logged('f1', 'INA')], 'INA'), isEmpty);
      });
    });

    test('is nothing for a fuel that forecourt does not sell', () {
      // Another Petrol sells it, and the brand alone would answer with that
      // one's price. The forecourt is known, and it has none.
      final pula = forecourt(
        13,
        'PM PULA',
        chain: 'Petrol',
        diesel: 1.55,
        petrol: 1.45,
      );

      expect(
        postedPriceAt(
          stations: [rovinj, pula],
          stationName: 'Petrol',
          fuelTypeId: 1,
        ),
        1.45,
      );
      expect(
        postedPriceAt(
          stations: [rovinj, pula],
          stationName: 'Petrol',
          stationRefs: const [11],
          fuelTypeId: 1,
        ),
        isNull,
      );
    });
  });
}
