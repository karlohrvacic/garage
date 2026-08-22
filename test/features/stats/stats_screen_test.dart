import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/stats/providers/stats_providers.dart';
import 'package:garage/features/stats/screens/stats_screen.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import 'package:garage/domain/stats/stats_section.dart';
import 'package:garage/features/stats/providers/stats_section_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_screen.dart';

FuelEntry fill(
  String id,
  int odometerKm, {
  double total = 62,
  double volumeL = 40,
  String? station,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 5, 1).add(Duration(days: odometerKm ~/ 100)),
    odometerKm: odometerKm,
    volumeL: volumeL,
    pricePerL: total / volumeL,
    total: total,
    fullTank: true,
    missedFill: false,
    station: station,
    createdBy: 'u1',
  );
}

/// Fill-ups alternating between two stations, one of them consistently
/// thirstier. [thirstyLiters] is what the second station puts in over the same
/// 500 km, so the gap is controllable.
List<FuelEntry> twoStations({double thirstyLiters = 45}) {
  final entries = <FuelEntry>[];
  var km = 1000;
  for (var i = 0; i < 10; i++) {
    final thirsty = i.isOdd;
    entries.add(
      fill(
        'f\$i',
        km,
        volumeL: thirsty ? thirstyLiters : 30,
        station: thirsty ? 'Shell' : 'INA',
      ),
    );
    km += 500;
  }
  return entries;
}

StatsData statsWith({
  List<FuelEntry> fuel = const [],
  List<ServiceEntry> services = const [],
  List<CostEntry> costs = const [],
  List<OdometerEntry> readings = const [],
  List<TripEntry> trips = const [],
  List<IncomeEntry> income = const [],
}) {
  return StatsData(
    fuel: fuel,
    services: services,
    costs: costs,
    readings: readings,
    trips: trips,
    income: income,
    economy: FuelEconomy.compute(fuel),
    readingsPerVehicle: [
      [
        for (final entry in fuel)
          OdometerReading(
            date: entry.date,
            km: entry.odometerKm,
            source: OdometerSource.fuel,
          ),
        for (final entry in readings)
          OdometerReading(
            date: entry.date,
            km: entry.odometerKm,
            source: OdometerSource.reading,
          ),
      ],
    ],
  );
}

class _Fleet extends Notifier<List<Vehicle>> {
  @override
  List<Vehicle> build() => [
    testVehicle('v1', nickname: 'Golf'),
    testVehicle('v2', nickname: 'Panda'),
  ];

  void keepOnly(List<Vehicle> vehicles) => state = vehicles;
}

final _fleet = NotifierProvider<_Fleet, List<Vehicle>>(_Fleet.new);

Future<NavigationLog> pumpStats(
  WidgetTester tester, {
  StatsData? data,
  Size surface = const Size(420, 1400),
  Set<StatsSection> hidden = const {},
  bool changeableFleet = false,
  double textScale = 1,
}) {
  final stats = data ?? statsWith();
  return pumpScreen(
    tester,
    // copyWith, not a fresh MediaQueryData: a bare one has a zero size, and
    // every adaptive layout in the app asks MediaQuery how wide the window is.
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: const StatsScreen(),
      ),
    ),
    initialLocation: '/stats',
    surface: surface,
    overrides: [
      if (hidden.isNotEmpty)
        hiddenStatsSectionsProvider.overrideWith(() => _FixedSections(hidden)),
      if (changeableFleet)
        vehiclesProvider.overrideWith((ref) async => ref.watch(_fleet))
      else
        vehiclesProvider.overrideWith(
          (ref) async => [testVehicle('v1', nickname: 'Golf')],
        ),
      statsDataProvider(null).overrideWith((ref) async => stats),
      statsDataProvider('v1').overrideWith((ref) async => stats),
      statsDataProvider('v2').overrideWith((ref) async => stats),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('it survives a large accessibility text scale', (tester) async {
    // The vehicle picker used to sit in the app bar beside the title, and a
    // toolbar is a fixed-width row with nowhere to give: at twice the default
    // text size the title, a car's name and the customise button overflowed it
    // by 46 pixels. The picker is a filter now, and lives with the other one.
    await pumpStats(tester, textScale: 2);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the vehicle filter is still there at that size', (tester) async {
    // Surviving by hiding the control would pass the test above and lose the
    // filter for exactly the people who most need the layout to hold.
    await pumpStats(tester, textScale: 2);
    await tester.pumpAndSettle();

    expect(find.text('All vehicles'), findsWidgets);
  });

  testWidgets('the car you were looking at going away does not break it', (
    tester,
  ) async {
    // Another member transfers or deletes it while the screen is open. A
    // dropdown holding a value its items no longer offer throws.
    await pumpStats(tester, changeableFleet: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panda').last);
    await tester.pumpAndSettle();

    ProviderScope.containerOf(
      tester.element(find.byType(StatsScreen)),
    ).read(_fleet.notifier).keepOnly([testVehicle('v1', nickname: 'Golf')]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('every stats tab is offered', (tester) async {
    await pumpStats(tester);
    await tester.pumpAndSettle();

    expect(find.text('Fill-ups'), findsWidgets);
    expect(find.text('Costs'), findsWidgets);
    expect(find.text('Distance'), findsWidgets);
    expect(find.text('Trips'), findsWidgets);
  });

  testWidgets('income is set against cost as a balance', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(
        costs: [
          CostEntry(
            id: 'c1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 3),
            category: CostCategories.insurance,
            amount: 300,
            createdBy: 'u1',
          ),
        ],
        income: [
          IncomeEntry(
            id: 'i1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 4),
            category: IncomeCategories.vehicleSale,
            amount: 500,
            createdBy: 'u1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Costs').first);
    await tester.pumpAndSettle();

    // 500 in against 300 out. Asserted inside the card so a 200 somewhere
    // else on the screen cannot pass for it.
    expect(
      find.descendant(
        of: find.byKey(const Key('stats-balance')),
        matching: find.textContaining('200'),
      ),
      findsWidgets,
    );
  });

  testWidgets('the trips tab splits business from private', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(
        trips: [
          TripEntry(
            id: 't1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 4),
            distanceKm: 120,
            purpose: TripPurpose.business,
            createdBy: 'u1',
          ),
          TripEntry(
            id: 't2',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 5),
            distanceKm: 30,
            purpose: TripPurpose.private,
            createdBy: 'u1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trips').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('150 km'), findsWidgets);
    expect(find.text('Business'), findsWidgets);
    expect(find.text('Private'), findsWidgets);
  });

  testWidgets('a household with no data says so', (tester) async {
    await pumpStats(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Not enough data'), findsWidgets);
  });

  testWidgets('fill-up figures are summarised', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500, total: 70)]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Fill-ups'), findsWidgets);
    expect(find.textContaining('l'), findsWidgets);
  });

  testWidgets('the costs tab totals spend with and without fuel', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(
        fuel: [fill('f1', 50000)],
        costs: [
          CostEntry(
            id: 'c1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 3, 1),
            category: CostCategories.insurance,
            amount: 300,
            createdBy: 'u1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Costs').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('362'), findsWidgets);
    expect(find.textContaining('300'), findsWidgets);
  });

  testWidgets('the distance tab reports what the odometer covered', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Distance').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('500 km'), findsWidgets);
  });

  testWidgets('a vehicle can be picked out of the fleet', (tester) async {
    await pumpStats(tester, data: statsWith(fuel: [fill('f1', 50000)]));
    await tester.pumpAndSettle();

    expect(find.text('All vehicles'), findsWidgets);
  });

  testWidgets('a desktop window gets more than a reading column', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
      surface: const Size(1500, 1000),
    );
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(TabBarView)).width;
    expect(
      width,
      greaterThan(GarageBreakpoints.contentMaxWidth),
      reason: 'charts and comparison figures are what the window is for',
    );
    expect(width, lessThanOrEqualTo(GarageBreakpoints.wideContentMaxWidth));
  });

  testWidgets('stat cards pair up into two columns on a desktop window', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
      surface: const Size(1500, 1000),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('stats-fill-ups'))).dx,
      isNot(tester.getTopLeft(find.byKey(const Key('stats-fuel-volume'))).dx),
    );
  });

  testWidgets('a section heading keeps its own column on a desktop window', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(
        fuel: [fill('f1', 50000), fill('f2', 50500)],
        costs: [
          CostEntry(
            id: 'c1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 3),
            category: CostCategories.insurance,
            amount: 300,
            createdBy: 'u1',
          ),
        ],
      ),
      surface: const Size(1500, 1000),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Costs').first);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('CATEGORIES')).dx,
      tester
          .getTopLeft(
            find.descendant(
              of: find.byKey(const Key('stats-categories')),
              matching: find.byType(Card),
            ),
          )
          .dx,
      reason:
          'a heading in one column and its card in the other reads as '
          'two unrelated sections',
    );
  });

  testWidgets('the same stat cards stack in one column on a phone', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('stats-fill-ups'))).dx,
      tester.getTopLeft(find.byKey(const Key('stats-fuel-volume'))).dx,
    );
  });

  testWidgets('the period is all time until something else is picked', (
    tester,
  ) async {
    await pumpStats(tester, data: statsWith(fuel: [fill('f1', 50000)]));
    await tester.pumpAndSettle();

    expect(find.text('All time'), findsOneWidget);
    expect(find.textContaining('1 entry'), findsOneWidget);
  });

  testWidgets('picking a period drops everything outside it', (tester) async {
    // f1 is dated 2026-05-01 + 500 days, which is well outside "this month"
    // however the test clock stands; the point is that the count follows the
    // period rather than the whole log.
    await pumpStats(
      tester,
      data: statsWith(
        fuel: [fill('f1', 50000), fill('f2', 50500)],
        costs: [
          CostEntry(
            id: 'c1',
            vehicleId: 'v1',
            date: DateTime.utc(2019, 3, 1),
            category: CostCategories.insurance,
            amount: 300,
            createdBy: 'u1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3 entries'), findsOneWidget);

    // The chips scroll horizontally on a phone; the later ones start off-screen.
    await tester.ensureVisible(
      find.byKey(const Key('stats-period-previousMonth')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stats-period-previousMonth')));
    await tester.pumpAndSettle();

    expect(find.textContaining('No entries'), findsOneWidget);
    expect(find.textContaining('3 entries'), findsNothing);
  });

  testWidgets('a total says what it works out to per day', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('By day'), findsWidgets);
  });

  testWidgets('a hidden section is not drawn', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
      hidden: {StatsSection.summary},
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats-fill-ups')), findsNothing);
  });

  testWidgets('hiding everything explains the empty screen', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
      hidden: StatsSection.values.toSet(),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Everything is hidden'), findsOneWidget);
  });

  testWidgets('the customise sheet lists every section', (tester) async {
    await pumpStats(tester, data: statsWith(fuel: [fill('f1', 50000)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    for (final section in StatsSection.values) {
      expect(
        find.byKey(Key('stats-section-${section.key}')),
        findsOneWidget,
        reason: 'every section has to be reachable to be turned off',
      );
    }
  });

  testWidgets('"all time" measures rates over the days actually logged', (
    tester,
  ) async {
    // The unbounded range is 1900 to 2200 so nothing is filtered out. Using
    // those ends as a real span made every per-day figure a total divided by
    // three centuries, and put the monthly bar chart in the year 2200.
    await pumpStats(
      tester,
      data: statsWith(
        costs: [
          CostEntry(
            id: 'c1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 1),
            category: CostCategories.insurance,
            amount: 310,
            createdBy: 'u1',
          ),
          CostEntry(
            id: 'c2',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 31),
            category: CostCategories.insurance,
            amount: 0,
            createdBy: 'u1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Costs').first);
    await tester.pumpAndSettle();

    // €310 over the 31 days logged is €10 a day. Asserted inside the card it
    // belongs to, because over 1900–2200 the same figure is €0.003 and a
    // looser finder matches something else on the screen and passes anyway.
    expect(
      find.descendant(
        of: find.byKey(const Key('stats-total-with-fuel')),
        matching: find.textContaining('10.000'),
      ),
      findsOneWidget,
    );
  });

  // Fuel brand is a small effect and how the car was driven is a large one, so
  // this section is built to stay quiet: it needs two stations with enough
  // tanks behind them AND a gap wider than the spread one driver produces
  // between a motorway month and a city one.
  group('economy by station', () {
    testWidgets('appears when two stations differ by more than the noise', (
      tester,
    ) async {
      await pumpStats(tester, data: statsWith(fuel: twoStations()));
      await tester.pumpAndSettle();

      expect(find.text('ECONOMY BY STATION'), findsOneWidget);
      expect(find.text('INA'), findsWidgets);
      expect(find.text('Shell'), findsWidgets);
    });

    testWidgets('says how many tanks each figure rests on', (tester) async {
      await pumpStats(tester, data: statsWith(fuel: twoStations()));
      await tester.pumpAndSettle();

      expect(find.textContaining('tanks'), findsWidgets);
    });

    testWidgets('always carries the caveat', (tester) async {
      // Not fine print to be trimmed: without it the section reads as advice
      // to change where you buy fuel, which the data does not support.
      await pumpStats(tester, data: statsWith(fuel: twoStations()));
      await tester.pumpAndSettle();

      expect(find.textContaining('An observation, not advice'), findsOneWidget);
    });

    testWidgets('stays away when the two stations are much of a muchness', (
      tester,
    ) async {
      // 30 l against 30.3 l over the same distance is a 1% gap — noise.
      await pumpStats(
        tester,
        data: statsWith(fuel: twoStations(thirstyLiters: 30.3)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ECONOMY BY STATION'),
        findsNothing,
        reason: 'a card saying "no difference" is worse than no card',
      );
    });

    testWidgets('stays away when only one station was ever named', (
      tester,
    ) async {
      await pumpStats(
        tester,
        data: statsWith(
          fuel: [
            for (var i = 0; i < 6; i++)
              fill('f\$i', 1000 + i * 500, station: 'INA'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ECONOMY BY STATION'),
        findsNothing,
        reason: '"better at INA" needs something to be better than',
      );
    });

    testWidgets('stays away when no station was recorded at all', (
      tester,
    ) async {
      await pumpStats(
        tester,
        data: statsWith(
          fuel: [for (var i = 0; i < 6; i++) fill('f\$i', 1000 + i * 500)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ECONOMY BY STATION'), findsNothing);
    });
  });
}

/// A visibility set fixed for the test, so a case about what is drawn does not
/// depend on how quickly the stored preference loads.
class _FixedSections extends HiddenStatsSections {
  _FixedSections(this._hidden);

  final Set<StatsSection> _hidden;

  @override
  Set<StatsSection> build() {
    loaded = Future.value();
    return _hidden;
  }
}
