import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/station_picks.dart';

FuelStation station(
  int id, {
  required double price,
  String name = 'INA',
  String fuelName = 'Eurosuper 95',
  int fuelTypeId = 1,
}) {
  return FuelStation(
    id: id,
    name: name,
    brand: name,
    address: null,
    place: null,
    lat: 45,
    lng: 16,
    prices: [
      StationPrice(fuelName: fuelName, fuelTypeId: fuelTypeId, price: price),
    ],
  );
}

RankedStation at(FuelStation station, double km) =>
    RankedStation(station: station, distanceKm: km);

void main() {
  group('picking a station', () {
    final nearby = [
      at(station(1, price: 1.60), 1),
      at(station(2, price: 1.45), 12),
      at(station(3, price: 1.55), 3),
    ];

    test('the nearest is the nearest, whatever it charges', () {
      expect(StationPicks.from(nearby, fuelTypeId: 1).nearest?.station.id, 1);
    });

    test('the cheapest is the cheapest, however far away', () {
      expect(StationPicks.from(nearby, fuelTypeId: 1).cheapest?.station.id, 2);
    });

    test('a station that does not sell the fuel is not a candidate', () {
      final picks = StationPicks.from([
        at(station(9, price: 1.10, fuelTypeId: 3), 1),
        ...nearby,
      ], fuelTypeId: 1);

      expect(picks.nearest?.station.id, 1);
    });

    test('nothing to pick from picks nothing rather than throwing', () {
      final picks = StationPicks.from(const [], fuelTypeId: 1);

      expect(picks.nearest, isNull);
      expect(picks.cheapest, isNull);
      expect(picks.bestValue, isNull);
    });

    test('a station with no known distance can still be the cheapest', () {
      // The web often has no position at all, and a price list is still useful.
      final picks = StationPicks.from([
        RankedStation(station: station(1, price: 1.60), distanceKm: null),
        RankedStation(station: station(2, price: 1.45), distanceKm: null),
      ], fuelTypeId: 1);

      expect(picks.cheapest?.station.id, 2);
      expect(picks.nearest, isNull);
    });
  });

  group('the pick that accounts for getting there', () {
    // 40 litres bought. Station 2 is 15 cents cheaper: €6.00 saved. Getting
    // there and back is 24 km at 8 l/100km = 1.92 litres, about €2.80. Worth
    // it.
    test('prefers a cheaper station when the detour pays for itself', () {
      final picks = StationPicks.from(
        [at(station(1, price: 1.60), 1), at(station(2, price: 1.45), 12)],
        fuelTypeId: 1,
        litres: 40,
        litersPer100Km: 8,
      );

      expect(picks.bestValue?.station.id, 2);
    });

    test('refuses a detour that costs more than it saves', () {
      // A cent a litre on 40 litres is €0.40; 60 km of driving is not.
      final picks = StationPicks.from(
        [at(station(1, price: 1.60), 1), at(station(2, price: 1.59), 30)],
        fuelTypeId: 1,
        litres: 40,
        litersPer100Km: 8,
      );

      expect(picks.bestValue?.station.id, 1);
    });

    test('is simply the cheapest when nothing is known about the car', () {
      // Without a consumption figure there is no honest way to price a
      // detour, so this does not invent one.
      final picks = StationPicks.from([
        at(station(1, price: 1.60), 1),
        at(station(2, price: 1.45), 30),
      ], fuelTypeId: 1);

      expect(picks.bestValue?.station.id, 2);
    });
  });

  group('what fuel costs around here', () {
    test(
      'averages each grade separately, because they are different fuels',
      () {
        final averages = StationPicks.areaAverages([
          at(station(1, price: 1.60, fuelName: 'Eurosuper 95'), 1),
          at(station(2, price: 1.70, fuelName: 'Eurosuper 95'), 2),
          at(station(3, price: 1.90, fuelName: 'Super 100'), 3),
        ]);

        expect(averages.map((a) => a.fuelName), ['Eurosuper 95', 'Super 100']);
        expect(averages.first.averagePrice, closeTo(1.65, 0.001));
        expect(averages.first.stations, 2);
      },
    );

    test('orders by how many stations sell it, so the common grade leads', () {
      final averages = StationPicks.areaAverages([
        at(station(1, price: 1.90, fuelName: 'Super 100'), 1),
        at(station(2, price: 1.60, fuelName: 'Eurosuper 95'), 2),
        at(station(3, price: 1.70, fuelName: 'Eurosuper 95'), 3),
      ]);

      expect(averages.first.fuelName, 'Eurosuper 95');
    });

    test('only counts stations inside the radius', () {
      final averages = StationPicks.areaAverages([
        at(station(1, price: 1.60), 1),
        at(station(2, price: 2.60), 80),
      ], radiusKm: 10);

      expect(averages.single.stations, 1);
      expect(averages.single.averagePrice, 1.60);
    });

    test('says nothing rather than averaging an empty area', () {
      expect(StationPicks.areaAverages(const []), isEmpty);
    });
  });
}
