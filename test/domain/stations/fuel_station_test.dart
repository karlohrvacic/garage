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

  test('a price of zero is not a price', () {
    // The ministry's feed carries `cijena: 0` for a pump a station is not
    // currently selling from. Read as a real price it wins every comparison,
    // so the app announced a station as the cheapest around at 0.00 € — which
    // is both wrong and the most eye-catching thing on the screen.
    final withZero = {
      ...json,
      'postajas': [
        {
          'id': 3,
          'naziv': 'Zero price',
          'obveznik_id': 5,
          'long': '45.8000',
          'lat': '15.9000',
          'cjenici': [
            {'id': 200, 'gorivo_id': 10, 'cijena': 0},
            {'id': 201, 'gorivo_id': 11, 'cijena': 1.62},
          ],
        },
      ],
    };

    final station = parseStations(withZero).single;

    expect(
      station.cheapestFor(1),
      isNull,
      reason:
          'a station not selling petrol has no petrol price, not a free one',
    );
    expect(
      station.prices,
      hasLength(1),
      reason:
          'the zero must not reach the price list on the detail sheet '
          'either, where it would read as an offer',
    );
    expect(station.cheapestFor(2), 1.62, reason: 'the real price still stands');
  });

  test('a negative price is not a price either', () {
    final withNegative = {
      ...json,
      'postajas': [
        {
          'id': 4,
          'naziv': 'Negative price',
          'obveznik_id': 5,
          'long': '45.8000',
          'lat': '15.9000',
          'cjenici': [
            {'id': 202, 'gorivo_id': 10, 'cijena': -1.2},
          ],
        },
      ],
    };

    expect(parseStations(withNegative).single.cheapestFor(1), isNull);
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
