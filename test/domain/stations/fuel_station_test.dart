import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';

void main() {
  final json = {
    'obvezniks': [
      {'id': 5, 'naziv': 'INA', 'logo': null},
    ],
    'tip_gorivas': [
      {'id': 1, 'tip_goriva': 'Benzinska goriva'},
      {'id': 2, 'tip_goriva': 'Dizelska goriva'},
    ],
    'vrsta_gorivas': [
      {'id': 1, 'vrsta_goriva': 'Eurosuper 95', 'tip_goriva_id': 1},
      {'id': 3, 'vrsta_goriva': 'Eurodizel', 'tip_goriva_id': 2},
    ],
    'gorivos': [
      {'id': 10, 'naziv': 'euroSUPER 95', 'vrsta_goriva_id': 1},
      {'id': 11, 'naziv': 'eurodizel', 'vrsta_goriva_id': 3},
    ],
    'postajas': [
      {
        'id': 1,
        'naziv': 'BP Zagreb',
        'adresa': 'Ilica 1',
        'mjesto': 'Zagreb',
        'obveznik_id': 5,
        // The upstream dataset swaps the coordinate fields.
        'long': '45.8150',
        'lat': '15.9819',
        'cjenici': [
          {'id': 100, 'gorivo_id': 10, 'cijena': 1.54},
          {'id': 101, 'gorivo_id': 11, 'cijena': 1.62},
        ],
      },
      {
        'id': 2,
        'naziv': 'No coordinates',
        'obveznik_id': 5,
        'long': null,
        'lat': null,
        'cjenici': const [],
      },
    ],
  };

  test('parses stations, resolving brand and fuel labels', () {
    final stations = parseStations(json);

    expect(stations, hasLength(1));
    final station = stations.single;
    expect(station.name, 'BP Zagreb');
    expect(station.brand, 'INA');
    expect(station.lat, closeTo(45.8150, 0.0001));
    expect(station.lng, closeTo(15.9819, 0.0001));
    expect(station.prices, hasLength(2));
    expect(station.cheapestFor(1), 1.54);
    expect(station.cheapestFor(2), 1.62);
    expect(station.cheapestFor(3), isNull);
  });

  test('haversine measures Zagreb to Split within tolerance', () {
    final km = haversineKm(
      lat1: 45.8150,
      lng1: 15.9819,
      lat2: 43.5081,
      lng2: 16.4402,
    );

    expect(km, closeTo(259, 5));
  });
}
