import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/station_picks.dart';
import 'package:garage/features/fuel/providers/pump_providers.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:geolocator/geolocator.dart';

import '../../support/pump_screen.dart' show testVehicle;

FuelStation forecourt(int id, String name, {double? petrol, double? lpg}) =>
    FuelStation(
      id: id,
      name: name,
      brand: '$name d.o.o.',
      address: 'Ilica 1',
      place: 'Zagreb',
      lat: 45.8,
      lng: 15.98,
      prices: [
        if (petrol != null)
          StationPrice(fuelName: 'eurosuper 95', fuelTypeId: 1, price: petrol),
        if (lpg != null)
          StationPrice(fuelName: 'autoplin', fuelTypeId: 3, price: lpg),
      ],
    );

/// Sells autogas and nothing else, thirty metres away.
final autoplin = forecourt(7, 'Autoplin', lpg: 0.79);

/// Sells petrol, a hundred and twenty metres away.
final benzin = forecourt(8, 'Benzin', petrol: 1.62);

final here = Position(
  latitude: 45.8,
  longitude: 15.98,
  timestamp: DateTime.utc(2026, 9, 18),
  accuracy: 5,
  altitude: 120,
  altitudeAccuracy: 3,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

ProviderContainer between(
  List<RankedStation> nearby, {
  String fuelTypeKey = 'fuel_petrol',
  String? secondaryFuelTypeKey,
}) {
  final container = ProviderContainer(
    overrides: [
      grantedPositionProvider.overrideWith((ref) async => here),
      vehicleProvider('v1').overrideWith(
        (ref) async => testVehicle(
          'v1',
          fuelTypeKey: fuelTypeKey,
          secondaryFuelTypeKey: secondaryFuelTypeKey,
        ),
      ),
      nearbyStationsProvider.overrideWith((ref) async => nearby),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<String?> standingAt(ProviderContainer container, String? fuel) async {
  final match = await container.read(
    stationAtThePumpProvider((vehicleId: 'v1', fuelTypeKey: fuel)).future,
  );
  return match?.station.name;
}

void main() {
  final both = [
    RankedStation(station: autoplin, distanceKm: 0.03),
    RankedStation(station: benzin, distanceKm: 0.12),
  ];

  group('a petrol car on autogas', () {
    test('filling autogas is at the forecourt that sells only that', () async {
      final container = between(both, secondaryFuelTypeKey: 'fuel_lpg');

      expect(await standingAt(container, 'fuel_lpg'), 'Autoplin');
    });

    test(
      'filling petrol is not at a nearer one that sells only autogas',
      () async {
        // Matched on either fuel, the thirty-metre autogas forecourt won, and a
        // petrol fill-up was logged at a station that sells no petrol.
        final container = between(both, secondaryFuelTypeKey: 'fuel_lpg');

        expect(await standingAt(container, null), 'Benzin');
        expect(await standingAt(container, 'fuel_petrol'), 'Benzin');
      },
    );
  });

  test('a charge is at the forecourt the car\'s own fuel finds', () async {
    // A plug-in hybrid kept as petrol, charging where it also fills up. The
    // charger has no posted price; the forecourt is still where it is.
    final container = between([
      RankedStation(station: benzin, distanceKm: 0.05),
    ], secondaryFuelTypeKey: 'fuel_electric');

    expect(await standingAt(container, 'fuel_electric'), 'Benzin');
  });

  test('a petrol-only car is at no forecourt that sells no petrol', () async {
    final container = between([
      RankedStation(station: autoplin, distanceKm: 0.03),
    ]);

    expect(await standingAt(container, null), isNull);
  });
}
