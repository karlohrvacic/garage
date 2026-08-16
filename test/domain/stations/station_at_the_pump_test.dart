import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/station_at_the_pump.dart';

FuelStation station({
  int id = 1,
  String name = 'Zagreb-Zapad',
  String brand = 'INA',
  double petrol = 1.54,
  double? diesel = 1.49,
}) {
  return FuelStation(
    id: id,
    name: name,
    brand: brand,
    address: 'Ilica 1',
    place: 'Zagreb',
    lat: 45.8,
    lng: 15.98,
    prices: [
      StationPrice(fuelName: 'euroSUPER 95', fuelTypeId: 1, price: petrol),
      if (diesel != null)
        StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: diesel),
    ],
  );
}

void main() {
  group('which ministry fuel a vehicle takes', () {
    test('maps the three the dataset prices', () {
      expect(StationFuel.forVehicle('fuel_petrol'), 1);
      expect(StationFuel.forVehicle('fuel_diesel'), 2);
      expect(StationFuel.forVehicle('fuel_lpg'), 3);
    });

    // An electric car does not fill up at a priced pump, and guessing petrol
    // for it would put a made-up price in the entry.
    test('has nothing for a fuel the dataset does not price', () {
      expect(StationFuel.forVehicle('fuel_electric'), isNull);
      expect(StationFuel.forVehicle('fuel_hybrid_plugin'), isNull);
      expect(StationFuel.forVehicle('something_new'), isNull);
    });
  });

  group('the station you are standing at', () {
    test('is the nearest one, when you are close enough to be at it', () {
      final match = StationAtThePump.match(
        nearby: [(station: station(name: 'Zapad'), distanceKm: 0.04)],
        fuelTypeId: 2,
      );

      expect(match?.station.name, 'Zapad');
      expect(match?.pricePerUnit, 1.49);
    });

    // Prefilling from a station down the road would put someone else's price
    // on the entry, which is worse than leaving it blank: it is wrong and it
    // looks deliberate.
    test('is nobody when the nearest is too far to be the one', () {
      expect(
        StationAtThePump.match(
          nearby: [(station: station(), distanceKm: 1.2)],
          fuelTypeId: 2,
        ),
        isNull,
      );
    });

    test('is nobody without a position at all', () {
      expect(
        StationAtThePump.match(
          nearby: [(station: station(), distanceKm: null)],
          fuelTypeId: 2,
        ),
        isNull,
      );
    });

    test('skips one that is close but does not sell this fuel', () {
      final match = StationAtThePump.match(
        nearby: [
          (
            station: station(id: 1, name: 'Petrol only', diesel: null),
            distanceKm: 0.03,
          ),
          (station: station(id: 2, name: 'Sells diesel'), distanceKm: 0.09),
        ],
        fuelTypeId: 2,
      );

      expect(match?.station.name, 'Sells diesel');
    });

    test('is nobody when the fuel is one the dataset does not price', () {
      expect(
        StationAtThePump.match(
          nearby: [(station: station(), distanceKm: 0.02)],
          fuelTypeId: null,
        ),
        isNull,
      );
    });

    test('prefers the closer of two that both sell it', () {
      final match = StationAtThePump.match(
        nearby: [
          (station: station(id: 1, name: 'Further'), distanceKm: 0.2),
          (station: station(id: 2, name: 'Closer'), distanceKm: 0.05),
        ],
        fuelTypeId: 2,
      );

      expect(match?.station.name, 'Closer');
    });
  });
}
