import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/features/stations/data/stations_repository.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStationsRepository implements StationsRepository {
  FakeStationsRepository({this.stations = const [], this.trend = const []});

  final List<FuelStation> stations;
  final List<TrendPoint> trend;

  @override
  Future<List<FuelStation>> fetchStations() async => stations;

  @override
  Future<List<TrendPoint>> fetchTrend() async => trend;
}

FuelStation station({
  int id = 1,
  String name = 'BP Zagreb',
  double lat = 45.8150,
  double lng = 15.9819,
}) {
  return FuelStation(
    id: id,
    name: name,
    brand: 'INA',
    address: 'Ilica 1',
    place: 'Zagreb',
    lat: lat,
    lng: lng,
    prices: const [
      StationPrice(fuelName: 'euroSUPER 95', fuelTypeId: 1, price: 1.54),
    ],
  );
}

Position position({double lat = 45.8150, double lng = 15.9819}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 8, 1),
    accuracy: 5,
    altitude: 120,
    altitudeAccuracy: 3,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

ProviderContainer containerWith({
  required FakeStationsRepository repository,
  Position? deviceposition,
}) {
  final container = ProviderContainer(
    overrides: [
      stationsRepositoryProvider.overrideWithValue(repository),
      positionProvider.overrideWith((ref) async => deviceposition),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('stations come straight from the repository', () async {
    final container = containerWith(
      repository: FakeStationsRepository(stations: [station()]),
    );

    final stations = await container.read(stationsProvider.future);

    expect(stations.single.name, 'BP Zagreb');
  });

  test('the price trend comes straight from the repository', () async {
    final container = containerWith(
      repository: FakeStationsRepository(
        trend: [
          TrendPoint(
            date: DateTime.utc(2026, 7, 1),
            fuelTypeId: 2,
            avgPrice: 1.62,
          ),
        ],
      ),
    );

    final trend = await container.read(priceTrendProvider.future);

    expect(trend.single.avgPrice, 1.62);
  });

  group('nearby stations', () {
    test('measure distance from the device position', () async {
      final container = containerWith(
        repository: FakeStationsRepository(stations: [station()]),
        deviceposition: position(lat: 45.8000, lng: 15.9800),
      );

      final nearby = await container.read(nearbyStationsProvider.future);

      expect(nearby.single.distanceKm, closeTo(1.68, 0.1));
    });

    test('carry no distance when the position is unavailable', () async {
      final container = containerWith(
        repository: FakeStationsRepository(stations: [station()]),
      );

      final nearby = await container.read(nearbyStationsProvider.future);

      expect(nearby.single.distanceKm, isNull);
      expect(nearby.single.station.name, 'BP Zagreb');
    });

    test('keep every station, leaving filtering to the screen', () async {
      final container = containerWith(
        repository: FakeStationsRepository(
          stations: [
            station(id: 1),
            station(id: 2, name: 'Far away'),
          ],
        ),
        deviceposition: position(),
      );

      final nearby = await container.read(nearbyStationsProvider.future);

      expect(nearby, hasLength(2));
    });
  });

  group('favourites', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('start empty', () async {
      final container = containerWith(repository: FakeStationsRepository());

      expect(container.read(favouriteStationsProvider), isEmpty);
    });

    test('load what a previous session starred', () async {
      SharedPreferences.setMockInitialValues({
        'favourite_stations': ['7', '9'],
      });
      final container = containerWith(repository: FakeStationsRepository());

      container.read(favouriteStationsProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(favouriteStationsProvider), {7, 9});
    });

    test('toggling adds, then removes, and persists both ways', () async {
      final container = containerWith(repository: FakeStationsRepository());
      final controller = container.read(favouriteStationsProvider.notifier);

      await controller.toggle(3);
      expect(container.read(favouriteStationsProvider), {3});
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'favourite_stations',
        ),
        ['3'],
      );

      await controller.toggle(3);
      expect(container.read(favouriteStationsProvider), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getStringList(
          'favourite_stations',
        ),
        isEmpty,
      );
    });
  });
}
