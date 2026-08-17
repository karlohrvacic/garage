import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/features/stations/data/stations_repository.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/stations/screens/stations_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_screen.dart';

FuelStation station({
  required int id,
  required String name,
  double petrol = 1.54,
  double? diesel,
  double distanceLat = 45.8,
}) {
  return FuelStation(
    id: id,
    name: name,
    brand: 'INA',
    address: 'Ilica 1',
    place: 'Zagreb',
    lat: distanceLat,
    lng: 15.98,
    prices: [
      StationPrice(fuelName: 'euroSUPER 95', fuelTypeId: 1, price: petrol),
      if (diesel != null)
        StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: diesel),
    ],
  );
}

Future<NavigationLog> pumpStations(
  WidgetTester tester, {
  List<NearbyStation> nearby = const [],
  List<TrendPoint> trend = const [],
  Size surface = const Size(400, 900),
}) {
  return pumpScreen(
    tester,
    const StationsScreen(),
    initialLocation: '/stations',
    surface: surface,
    overrides: [
      nearbyStationsProvider.overrideWith((ref) async => nearby),
      priceTrendProvider.overrideWith((ref) async => trend),
    ],
  );
}

/// Where a station's row sits in the rendered list. Rows are titled
/// "brand · name", so the station name is matched as a substring.
///
/// Scoped to the list itself: the picks card above it names two stations as
/// well, and counting every Text on the screen would measure that instead.
int positionOf(WidgetTester tester, String stationName) {
  final texts = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('station-list')),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data)
      .whereType<String>()
      .toList();
  final index = texts.indexWhere((text) => text.contains(stationName));
  expect(index, isNot(-1), reason: '$stationName is not in the list');
  return index;
}

/// A finder for a station's row in the list, ignoring the picks card.
Finder inList(String text) => find.descendant(
  of: find.byKey(const Key('station-list')),
  matching: find.textContaining(text),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the three fuel types are offered as filters', (tester) async {
    await pumpStations(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(3));
  });

  testWidgets('stations selling the chosen fuel are listed', (tester) async {
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: station(id: 1, name: 'BP Zagreb'),
          distanceKm: 2.4,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(inList('BP Zagreb'), findsOneWidget);
    expect(find.textContaining('1.54'), findsWidgets);
  });

  testWidgets('a station that does not sell the chosen fuel is hidden', (
    tester,
  ) async {
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: station(id: 1, name: 'Petrol only'),
          distanceKm: 1,
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Diesel'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Petrol only'), findsNothing);
  });

  testWidgets('with a position, the nearest station comes first', (
    tester,
  ) async {
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(station: station(id: 1, name: 'Far'), distanceKm: 12),
        NearbyStation(station: station(id: 2, name: 'Near'), distanceKm: 1),
      ],
    );
    await tester.pumpAndSettle();

    expect(positionOf(tester, 'Near'), lessThan(positionOf(tester, 'Far')));
  });

  testWidgets('without a position, the cheapest comes first', (tester) async {
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: station(id: 1, name: 'Pricey', petrol: 1.7),
          distanceKm: null,
        ),
        NearbyStation(
          station: station(id: 2, name: 'Cheap', petrol: 1.4),
          distanceKm: null,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(positionOf(tester, 'Cheap'), lessThan(positionOf(tester, 'Pricey')));
  });

  testWidgets('a favourite is pinned above the rest', (tester) async {
    SharedPreferences.setMockInitialValues({
      'favourite_stations': ['1'],
    });
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: station(id: 1, name: 'Starred', petrol: 1.9),
          distanceKm: null,
        ),
        NearbyStation(
          station: station(id: 2, name: 'Cheaper', petrol: 1.4),
          distanceKm: null,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      positionOf(tester, 'Starred'),
      lessThan(positionOf(tester, 'Cheaper')),
    );
  });

  testWidgets('no stations for the chosen fuel says so', (tester) async {
    await pumpStations(tester);
    await tester.pumpAndSettle();

    expect(find.text('No stations found.'), findsOneWidget);
  });

  // The prices come from the Croatian ministry's dataset, so someone opening
  // this abroad got the whole country listed as "nearby", nearest first, with
  // an average price beside it: a station 9,671 km away offered as a place to
  // fill up. Silence would have been better; saying where the data covers is
  // better still.
  group('opened outside the country the prices cover', () {
    testWidgets('says so rather than offering a station a continent away', (
      tester,
    ) async {
      await pumpStations(
        tester,
        nearby: [
          NearbyStation(
            station: station(id: 1, name: 'BP Zagreb'),
            distanceKm: 9671.7,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('BP Zagreb'), findsNothing);
      expect(
        find.textContaining('Croatia'),
        findsOneWidget,
        reason: 'the reader should learn which country the prices are for',
      );
    });

    testWidgets('and averages nothing as though it were down the road', (
      tester,
    ) async {
      await pumpStations(
        tester,
        nearby: [
          NearbyStation(
            station: station(id: 1, name: 'BP Zagreb'),
            distanceKm: 9671.7,
          ),
        ],
        trend: [
          TrendPoint(
            date: DateTime.utc(2026, 8, 10),
            fuelTypeId: 1,
            avgPrice: 1.83,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('AVERAGE NEARBY'), findsNothing);
      expect(
        find.text('NATIONAL AVERAGE'),
        findsOneWidget,
        reason: 'a national figure is still true from anywhere',
      );
    });

    testWidgets('a long drive inside the country is still shown', (
      tester,
    ) async {
      // Croatia is around 500 km end to end, so a station 180 km away is a
      // real answer for someone in a thin part of it.
      await pumpStations(
        tester,
        nearby: [
          NearbyStation(
            station: station(id: 1, name: 'BP Zagreb'),
            distanceKm: 180,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(inList('BP Zagreb'), findsOneWidget);
    });
  });

  testWidgets('a desktop window keeps the list in a reading column', (
    tester,
  ) async {
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: station(id: 1, name: 'BP Zagreb'),
          distanceKm: 2.4,
        ),
      ],
      surface: const Size(1500, 1000),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(ListView)).width,
      GarageBreakpoints.contentMaxWidth,
      reason:
          'the price sits at the far right of its row, and the question '
          'being asked is which name goes with which price',
    );
  });

  testWidgets('the cheapest and nearest stations are named at the top', (
    tester,
  ) async {
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: station(id: 1, name: 'Near', petrol: 1.70),
          distanceKm: 1,
        ),
        NearbyStation(
          station: station(id: 2, name: 'Far', petrol: 1.45),
          distanceKm: 12,
        ),
      ],
    );
    await tester.pumpAndSettle();

    final picks = find.byKey(const Key('station-picks'));
    expect(picks, findsOneWidget);
    expect(
      find.descendant(of: picks, matching: find.text('Near')),
      findsOneWidget,
      reason: 'the nearest is named',
    );
    expect(
      find.descendant(of: picks, matching: find.text('Far')),
      findsOneWidget,
      reason: 'the cheapest is named, even 12 km away',
    );
  });

  testWidgets('each grade gets its own local average, not one blended one', (
    tester,
  ) async {
    // 95 and 100 are different fuels at different prices; one figure covering
    // both is a number nobody can act on.
    await pumpStations(
      tester,
      nearby: [
        NearbyStation(
          station: FuelStation(
            id: 1,
            name: 'A',
            brand: 'INA',
            address: null,
            place: null,
            lat: 45.8,
            lng: 15.98,
            prices: const [
              StationPrice(
                fuelName: 'euroSUPER 95',
                fuelTypeId: 1,
                price: 1.60,
              ),
              StationPrice(fuelName: 'Super 100', fuelTypeId: 1, price: 1.90),
            ],
          ),
          distanceKm: 1,
        ),
      ],
    );
    await tester.pumpAndSettle();

    final averages = find.byKey(const Key('station-area-averages'));
    expect(averages, findsOneWidget);
    expect(
      find.descendant(of: averages, matching: find.text('euroSUPER 95')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: averages, matching: find.text('Super 100')),
      findsOneWidget,
    );
  });

  testWidgets('no picks are offered when nothing sells the chosen fuel', (
    tester,
  ) async {
    await pumpStations(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('station-picks')), findsNothing);
  });
}
