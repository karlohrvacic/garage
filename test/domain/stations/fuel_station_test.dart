import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';

void main() {
  test('a price below any real pump price is not the cheapest', () {
    // The open data has carried figures like 0.67 a litre, and the screen
    // promoted the lowest number it could find to its headline.
    const station = FuelStation(
      id: 1,
      name: 'Artefact',
      brand: null,
      address: null,
      place: null,
      lat: 45.8,
      lng: 15.98,
      prices: [
        StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: 0.67),
        StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: 1.52),
      ],
    );

    expect(station.cheapestFor(2), 1.52);
  });

  test('autogas is allowed to be genuinely cheap', () {
    // A floor set for petrol and diesel would hide real LPG prices, which
    // is the same mistake in the other direction.
    const station = FuelStation(
      id: 2,
      name: 'Autoplin',
      brand: null,
      address: null,
      place: null,
      lat: 45.8,
      lng: 15.98,
      prices: [StationPrice(fuelName: 'autoplin', fuelTypeId: 3, price: 0.68)],
    );

    expect(station.cheapestFor(3), 0.68);
  });

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

  group('the name a driver would recognise', () {
    FuelStation station(String name, {String? brand}) => FuelStation(
      id: 1,
      name: name,
      brand: brand,
      address: 'Ilica 1',
      place: 'Zagreb',
      lat: 45.8,
      lng: 15.9,
      prices: const [],
    );

    test('an internal sales-point code gives way to the brand', () {
      // Petrol files every forecourt as "PM - 00123" in `naziv`. Shown as the
      // headline it tells a driver nothing: it is a number in somebody's
      // stock system, not what is on the sign.
      expect(
        station('PM - 00123', brand: 'PETROL d.o.o.').displayName,
        'PETROL d.o.o.',
      );
    });

    test('a code with no brand behind it is still shown', () {
      // Better a code than a blank row: it is at least an identity, and the
      // address underneath is what places it anyway.
      expect(station('PM - 00123').displayName, 'PM - 00123');
    });

    test('a real name is left alone, brand or no brand', () {
      expect(
        station(
          'Krapina - Frana Galovića',
          brand: 'INA – Industrija nafte d.d.',
        ).displayName,
        'Krapina - Frana Galovića',
        reason: 'two INA forecourts in one city are what the name tells apart',
      );
      expect(station('Autoplin Sesvete').displayName, 'Autoplin Sesvete');
    });

    group('a name that opens with the word for a forecourt', () {
      // What the ministry's feed really holds, September 2026: Petrol files
      // all 202 of its stations as "PM <place>" (prodajno mjesto), and Tifon,
      // Lukoil, Adria Oil and AGS file theirs as "BP" or "BS <place>"
      // (benzinska postaja, benzinska stanica). None of them says whose
      // forecourt it is, and the fill-up sheet writes this name into the log.
      test('says whose forecourt it is instead', () {
        const feed = {
          ('PM POREČ, ŽBANDAJ', 'Petrol d.o.o.'): 'Petrol POREČ, ŽBANDAJ',
          ('BP MOKRICE', 'LUKOIL Croatia d.o.o.'): 'LUKOIL MOKRICE',
          ('BS Gospić', 'AGS Hrvatska d.o.o.'): 'AGS Gospić',
          ('BP Velika Gorica', 'KTC d.d.'): 'KTC Velika Gorica',
          ('B.P. LUČKO', 'Tifon d.o.o.'): 'Tifon LUČKO',
          ('BP Zagreb', 'INA – Industrija nafte d.d.'): 'INA Zagreb',
          // The feed does not always shout.
          ('bp eurotank', 'Mošunj d.o.o.'): 'Mošunj eurotank',
          ('Bp Srb', 'Norma d.o.o.'): 'Norma Srb',
        };

        for (final MapEntry(key: (name, brand), value: want) in feed.entries) {
          expect(station(name, brand: brand).displayName, want);
        }
      });

      test('keeps a name that already says so', () {
        const feed = {
          'GAS OIL - BP PULA': 'GasOil d.o.o.',
          'BP SANTINI': 'Santini d.o.o.',
          'B.P. Mikić': 'G.P.P. Mikić d.o.o.',
          'BP JOZINOVIĆ VRBANJA - POGON 4.': 'B.P. Jozinović',
          'BP ASSERIA OIL': 'asseriaoil',
        };

        for (final MapEntry(key: name, value: brand) in feed.entries) {
          expect(station(name, brand: brand).displayName, name);
        }
      });

      test('leaves alone a name that only looks like one', () {
        // "LPG Autoplin" is a name. Three capitals are not a forecourt, and
        // an operator is not always what is on the sign: Coral runs Shell's.
        expect(
          station('LPG Autoplin', brand: 'Kp Plin d.o.o.').displayName,
          'LPG Autoplin',
        );
        expect(
          station(
            'Shell Ivanja Reka',
            brand: 'Coral Croatia d.o.o.',
          ).displayName,
          'Shell Ivanja Reka',
        );
        expect(station('PM ROVINJ').displayName, 'PM ROVINJ');
      });

      test('still answers to the name older fill-ups were saved under', () {
        final petrol = station('PM ROVINJ', brand: 'Petrol d.o.o.');

        expect(petrol.answersTo('PM ROVINJ'), isTrue);
        expect(petrol.answersTo('petrol rovinj'), isTrue);
      });

      test('does not repeat the operator under a headline that names it', () {
        expect(
          station('PM ROVINJ', brand: 'Petrol d.o.o.').operatorName,
          isNull,
        );
      });
    });

    test('a station named only by a number gives way to the brand', () {
      expect(
        station('1042', brand: 'Crodux derivati dva').displayName,
        'Crodux derivati dva',
      );
    });

    test('a short word is a name, not a code', () {
      // "Tif 4" is somebody's forecourt. The rule looks for a word, and three
      // letters is a word.
      expect(station('Tif 4', brand: 'Tifon d.o.o.').displayName, 'Tif 4');
    });

    test('the operator is not repeated under a headline that is the brand', () {
      // "PETROL d.o.o. — PETROL d.o.o." reads as a rendering bug.
      expect(
        station('PM - 00123', brand: 'PETROL d.o.o.').operatorName,
        isNull,
      );
    });

    test('the operator still rides along under a real name', () {
      expect(
        station('Krapina - Frana Galovića', brand: 'INA').operatorName,
        'INA',
      );
    });
  });
  // The fill-up sheet writes this into the log. A driver says "INA" or
  // "Shell", not "Krapina - Frana Galovića" and not "PM POREČ, ŽBANDAJ", and
  // whether a name is a chain's needs the whole feed, so the feed decides it.
  group('the brand a fill-up is logged under', () {
    /// A feed in the ministry's shape: operators by id, and each station's
    /// name under the operator that files it. Coordinates everywhere unless a
    /// station is listed in [unplaced].
    Map<String, dynamic> feed(
      Map<int, String> operators,
      List<(int, String)> stations, {
      Set<String> unplaced = const {},
    }) {
      return {
        'obvezniks': [
          for (final MapEntry(key: id, value: name) in operators.entries)
            {'id': id, 'naziv': name},
        ],
        'postajas': [
          for (final (index, (operator, name)) in stations.indexed)
            {
              'id': 1000 + index,
              'naziv': name,
              'obveznik_id': operator,
              'long': unplaced.contains(name) ? null : '45.8',
              'lat': unplaced.contains(name) ? null : '15.9',
              'cjenici': const [],
            },
        ],
      };
    }

    /// Every chain in the feed of 17 September 2026 with three or more
    /// forecourts, three of its real names each, and what it trades under.
    const chains = {
      'INA': (
        'INA – Industrija nafte d.d.',
        [
          'Krapina -  Frana Galovića',
          'Imotski - Glavina Donja',
          'Rijeka-Škurinje',
        ],
      ),
      'Petrol': (
        'Petrol d.o.o.',
        ['PM POREČ, ŽBANDAJ', 'PM KONJŠČINA', 'PM ROVINJ'],
      ),
      'Tifon': ('Tifon d.o.o.', ['SLANO', 'BP LUČKO', 'BP ZAGREB ISTOK']),
      'LUKOIL': (
        'LUKOIL Croatia d.o.o.',
        ['BP MOKRICE', 'BP PRELOG', 'BP DICMO'],
      ),
      'Adria Oil': (
        'Adria Oil d.o.o.',
        ['BP PITOMAČA', 'BP MAKARSKA', 'BP VIŠKOVO'],
      ),
      'Shell': (
        'Coral Croatia d.o.o.',
        ['Shell Ivanja Reka', 'Shell Kanfanar', 'Shell Markuševec'],
      ),
      'KTC': ('KTC d.d.', ['BP Velika Gorica', 'Križevci', 'Virovitica']),
      'AGS': ('AGS Hrvatska d.o.o.', ['BS Gospić', 'BS Sinj', 'BS Vukovar']),
      'Dirus Projekt': (
        'Dirus Projekt d.o.o.',
        ['LIPIK', 'TUŠILOVIĆ ZAPAD', 'GLINA'],
      ),
      'Tri Bartola': (
        'Tri Bartola d.o.o.',
        ['BP VIR', 'BP GALOVAC', 'BP SUKOŠAN'],
      ),
      'Jozinović': (
        'B.P. Jozinović',
        [
          'BP JOZINOVIĆ VRBANJA - POGON 4.',
          'B.P. JOZINOVIĆ IVANKOVO',
          'B.P. JOZINOVIĆ OTOK',
        ],
      ),
      'Mikol': (
        'Mikol d.o.o.',
        [
          'MIKOL - BP ČAKOVEC',
          'MIKOL  -  BP KOPRIVNICA',
          'MIKOL  -  BP VARAŽDIN',
        ],
      ),
      'RIJEKA TRANS': (
        'RIJEKA TRANS D.O.O. ',
        ['BP PAG', 'BP KUKULJANOVO', 'BP KUKULJANOVO 2'],
      ),
    };

    test('a chain trades under the name on its sign', () {
      for (final MapEntry(key: want, value: (operator, names))
          in chains.entries) {
        final stations = parseStations(
          feed({1: operator}, [for (final name in names) (1, name)]),
        );

        expect(stations.map((station) => station.brandName).toSet(), {
          want,
        }, reason: operator);
      }
    });

    test('an operator that is not the sign is not the brand', () {
      // Coral Croatia runs Shell's forecourts and files every one as
      // "Shell …". A first word every station shares, that is no word for a
      // forecourt and that the operator's name does not carry, is the brand —
      // and "PM", which Petrol's all share, and "MIKOL", which Mikol's name
      // carries, are not exceptions to anything.
      final stations = parseStations(
        feed(
          {1: 'Coral Croatia d.o.o.'},
          [(1, 'Shell Kanfanar'), (1, 'SHELL Sesvete'), (1, 'Shell Zadar')],
        ),
      );

      expect(stations.map((station) => station.brandName).toSet(), {'Shell'});
    });

    test('a first word the stations do not all share is not the brand', () {
      final stations = parseStations(
        feed(
          {1: 'Coral Croatia d.o.o.'},
          [(1, 'Shell Kanfanar'), (1, 'Shell Zadar'), (1, 'Kanfanar')],
        ),
      );

      expect(stations.map((station) => station.brandName).toSet(), {'Coral'});
    });

    test('an independent keeps the name it is shown under', () {
      final stations = parseStations(
        feed(
          {1: 'Santini d.o.o.', 2: 'GasOil d.o.o.', 3: 'TOMICA BENZ d.o.o.'},
          [
            (1, 'BP SANTINI'),
            (2, 'GAS OIL - BP PULA'),
            (2, 'GAS OIL - BP POREČ'),
            (3, 'BP KLINČA SELA'),
          ],
        ),
      );

      expect(stations.map((station) => station.brandName), [
        'BP SANTINI',
        'GAS OIL - BP PULA',
        'GAS OIL - BP POREČ',
        'TOMICA BENZ KLINČA SELA',
      ]);
      for (final station in stations) {
        expect(station.brandName, station.displayName);
      }
    });

    test('a forecourt the feed cannot place still counts towards a chain', () {
      // The feed's own count, not the stations screen's: KTC files one of its
      // seventeen with no coordinates, and the chain is no smaller for it.
      final stations = parseStations(
        feed(
          {1: 'KTC d.d.'},
          [(1, 'BP Velika Gorica'), (1, 'Križevci'), (1, 'Virovitica')],
          unplaced: {'BP Velika Gorica'},
        ),
      );

      expect(stations, hasLength(2));
      expect(stations.map((station) => station.brandName).toSet(), {'KTC'});
    });

    test('the stations screen still tells two forecourts apart', () {
      final stations = parseStations(
        feed(
          {1: 'Petrol d.o.o.'},
          [(1, 'PM ROVINJ'), (1, 'PM KONJŠČINA'), (1, 'PM ZADAR')],
        ),
      );

      expect(stations.first.displayName, 'Petrol ROVINJ');
      expect(stations.first.brandName, 'Petrol');
    });

    test('a station built without the feed is taken for an independent', () {
      const station = FuelStation(
        id: 1,
        name: 'Zagreb-Zapad',
        brand: 'INA',
        address: null,
        place: 'Zagreb',
        lat: 45.8,
        lng: 15.98,
        prices: [],
      );

      expect(station.brandName, 'Zagreb-Zapad');
    });

    test('a chain station answers to its brand', () {
      final rovinj = parseStations(
        feed(
          {1: 'Petrol d.o.o.'},
          [(1, 'PM ROVINJ'), (1, 'PM KONJŠČINA'), (1, 'PM ZADAR')],
        ),
      ).first;

      expect(rovinj.answersTo('Petrol'), isTrue);
      expect(rovinj.answersTo(' PETROL '), isTrue);
      expect(rovinj.answersTo('PM ROVINJ'), isTrue);
      expect(rovinj.answersTo('Petrol ROVINJ'), isTrue);
      expect(rovinj.answersTo('Tifon'), isFalse);
    });
  });
}
