import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/timeline/screens/timeline_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import 'package:garage/features/attachments/providers/attachment_providers.dart';

import '../../support/pump_screen.dart';

TimelineItem item({
  TimelineKind kind = TimelineKind.fuel,
  DateTime? date,
  double? amount = 62,
  String vehicleId = 'v1',
  List<String> serviceTypeKeys = const [],
  String? costCategory,
  String createdBy = 'u1',
  String entryId = 'e1',
  String? notes,
  bool isIncome = false,
}) {
  return TimelineItem(
    kind: kind,
    entryId: entryId,
    date: date ?? DateTime.utc(2026, 7, 24),
    vehicleId: vehicleId,
    amount: amount,
    createdBy: createdBy,
    serviceTypeKeys: serviceTypeKeys,
    costCategory: costCategory,
    odometerKm: 51140,
    notes: notes,
    isIncome: isIncome,
  );
}

Future<NavigationLog> pumpTimeline(
  WidgetTester tester, {
  List<TimelineItem> items = const [],
  Size surface = const Size(400, 900),
  double textScale = 1,
  Locale? locale,
  Set<String> withAttachments = const {},
  List<EconomyPoint> points = const [],
}) {
  return pumpScreen(
    tester,
    const TimelineScreen(),
    initialLocation: '/timeline',
    surface: surface,
    textScale: textScale,
    locale: locale,
    overrides: [
      timelineProvider.overrideWith((ref) async => items),
      entriesWithAttachmentsProvider.overrideWith(
        (ref) async => withAttachments,
      ),
      vehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
      economyPointsProvider('v1').overrideWith((ref) async => points),
    ],
  );
}

void main() {
  testWidgets('search reaches the station a fill-up was at', (tester) async {
    // "Nothing matches that" is indistinguishable from "you never logged it".
    await pumpTimeline(
      tester,
      items: [
        TimelineItem(
          kind: TimelineKind.fuel,
          entryId: 'f1',
          date: DateTime.utc(2026, 9, 1),
          vehicleId: 'v1',
          amount: 58,
          createdBy: 'u1',
          detail: 'INA Zagreb',
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'INA');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches that.'), findsNothing);
    expect(find.text('Fuel'), findsWidgets);

    // And a query it does not carry hides the row, so a filter that ignored
    // the query entirely would not pass this.
    await tester.enterText(find.byType(TextField).first, 'Shell');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches that.'), findsOneWidget);
  });

  testWidgets('an empty history explains itself', (tester) async {
    await pumpTimeline(tester);
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('entries are grouped under their month', (tester) async {
    await pumpTimeline(
      tester,
      items: [
        item(date: DateTime.utc(2026, 7, 24)),
        item(date: DateTime.utc(2026, 7, 2)),
        item(date: DateTime.utc(2026, 6, 30)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('JULY 2026'), findsOneWidget);
    expect(find.text('JUNE 2026'), findsOneWidget);
  });

  testWidgets('a fill-up row names the vehicle and its cost', (tester) async {
    await pumpTimeline(tester, items: [item()]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Golf'), findsWidgets);
    // The month header and the closing line quote the same figure, so the row
    // is identified by the unsigned form only it uses.
    expect(find.text('€62.00'), findsOneWidget);
  });

  testWidgets('a fill-up row shows what its tank worked out to', (
    tester,
  ) async {
    // The per-tank figure lived only in the fuel log, a screen the seventh
    // critique found hard to reach; here it sits under the cost.
    await pumpTimeline(
      tester,
      items: [item(kind: TimelineKind.fuel, amount: 62, entryId: 'f2')],
      points: [
        EconomyPoint(
          entryId: 'f2',
          date: DateTime.utc(2026, 7, 24),
          odometerKm: 51140,
          litersPer100Km: 6.4,
          distanceKm: 500,
          volumeL: 32,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('l/100km'), findsOneWidget);
    expect(find.textContaining('6.4'), findsOneWidget);
  });

  testWidgets('a charge reads in kilowatt-hours on a car kept as petrol', (
    tester,
  ) async {
    // A plug-in hybrid's charges close tanks of their own, and each figure is
    // in what that tank held, whatever the car mainly takes.
    await pumpTimeline(
      tester,
      items: [item(kind: TimelineKind.fuel, amount: 15, entryId: 'c2')],
      points: [
        EconomyPoint(
          entryId: 'c2',
          date: DateTime.utc(2026, 7, 24),
          odometerKm: 51140,
          litersPer100Km: 16.7,
          distanceKm: 300,
          volumeL: 50,
          fuelTypeKey: 'fuel_electric',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('16.7 kWh/100km'), findsOneWidget);
    expect(find.textContaining('l/100km'), findsNothing);
  });

  testWidgets('a fill-up that closes no span shows its cost alone', (
    tester,
  ) async {
    await pumpTimeline(
      tester,
      items: [item(kind: TimelineKind.fuel, amount: 62, entryId: 'f1')],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('l/100km'), findsNothing);
    expect(find.textContaining('62'), findsWidgets);
  });

  testWidgets('a service row names what was done', (tester) async {
    await pumpTimeline(
      tester,
      items: [
        item(
          kind: TimelineKind.service,
          serviceTypeKeys: const ['service_oil_change'],
          amount: 210,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsOneWidget);
  });

  testWidgets('a cost row names its category', (tester) async {
    await pumpTimeline(
      tester,
      items: [
        item(
          kind: TimelineKind.cost,
          costCategory: CostCategories.insurance,
          amount: 320,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Insurance'), findsOneWidget);
  });

  testWidgets('a row names who logged the entry', (tester) async {
    await pumpScreen(
      tester,
      const TimelineScreen(),
      initialLocation: '/timeline',
      overrides: [
        timelineProvider.overrideWith((ref) async => [item()]),
        vehiclesProvider.overrideWith(
          (ref) async => [testVehicle('v1', nickname: 'Golf')],
        ),
        membersProvider.overrideWith(
          (ref) async => const [
            HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
          ],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Karlo'), findsWidgets);
  });

  testWidgets('the timeline tab is the selected one', (tester) async {
    await pumpTimeline(tester);
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.selectedIndex, 1);
  });

  testWidgets('tapping another tab navigates there', (tester) async {
    final log = await pumpTimeline(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.directions_car_outlined));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles'));
  });

  group('finding something in a long history', () {
    testWidgets('a term narrows the log to what matches', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(kind: TimelineKind.fuel),
          item(kind: TimelineKind.trip),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('timeline-search')),
        'nothing here matches this',
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing matches that.'), findsOneWidget);
    });

    testWidgets('clearing the search brings it all back', (tester) async {
      await pumpTimeline(tester, items: [item(kind: TimelineKind.fuel)]);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('timeline-search')),
        'nothing here matches this',
      );
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches that.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Nothing matches that.'), findsNothing);
    });

    testWidgets('a kind chip narrows to that kind', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(kind: TimelineKind.fuel),
          item(kind: TimelineKind.trip),
        ],
      );
      await tester.pumpAndSettle();

      // Scoped to the log: the chip strip above it carries the same words, and
      // an unscoped finder would be measuring the filter's own labels.
      Finder inLog(String text) => find.descendant(
        of: find.byKey(const Key('timeline-list')),
        matching: find.text(text),
      );

      expect(inLog('Trips'), findsOneWidget);

      // The kinds live behind the search field's filter button now: six chips
      // permanently above the list cost two or three rows on a phone, all of
      // it spent on a filter almost nobody has switched on.
      await tester.tap(find.byKey(const Key('timeline-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timeline-kind-fuel')));
      await tester.pumpAndSettle();
      expect(inLog('Trips'), findsNothing);
      expect(inLog('Fuel'), findsOneWidget, reason: 'the chosen kind stays');
    });
  });

  group('what a row does not say out loud', () {
    testWidgets('a note is searchable', (tester) async {
      // The note is often the only place the distinguishing detail lives —
      // which garage, which part, why this one was odd. Searching everything
      // except the free-text field misses the thing the person wrote down.
      await pumpTimeline(
        tester,
        items: [
          item(kind: TimelineKind.fuel, notes: 'Petrol at the INA on the ring'),
          item(kind: TimelineKind.trip),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('timeline-search')), 'INA');
      await tester.pumpAndSettle();

      Finder inLog(String text) => find.descendant(
        of: find.byKey(const Key('timeline-list')),
        matching: find.text(text),
      );

      expect(inLog('Fuel'), findsOneWidget);
      expect(inLog('Trips'), findsNothing);
    });

    testWidgets('and is marked, so the row worth opening looks it', (
      tester,
    ) async {
      await pumpTimeline(
        tester,
        items: [
          item(kind: TimelineKind.fuel, notes: 'Topped up before the trip'),
          item(kind: TimelineKind.trip),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
    });

    testWidgets('an entry with no note is not marked', (tester) async {
      await pumpTimeline(tester, items: [item(kind: TimelineKind.fuel)]);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });

    testWidgets('whitespace is not a note', (tester) async {
      await pumpTimeline(
        tester,
        items: [item(kind: TimelineKind.fuel, notes: '   ')],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);
    });

    testWidgets('an attachment is marked too', (tester) async {
      // Whether an entry carries a receipt was invisible from the list: the
      // only way to find out was to open it.
      await pumpTimeline(
        tester,
        items: [item(kind: TimelineKind.fuel, entryId: 'e1')],
        withAttachments: const {'e1'},
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.attach_file), findsOneWidget);
    });
  });

  testWidgets('the filter bar survives a large text scale', (tester) async {
    // A fixed-height box around text: the chips grew with the system font and
    // the 40px container did not. Plenty of people run 1.3 without thinking of
    // it as a setting.
    for (final scale in [1.0, 1.3, 1.6]) {
      await pumpTimeline(
        tester,
        items: [item(kind: TimelineKind.fuel)],
        textScale: scale,
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the chip strip overflows at $scale',
      );
      // Every kind, at every scale — in the sheet the filter button opens.
      // A lazy horizontal strip used to build only the chips that fit, so the
      // last filters existed with nothing on screen to say so.
      await tester.tap(find.byKey(const Key('timeline-filter')));
      await tester.pumpAndSettle();

      expect(
        find.byType(CheckboxListTile),
        findsNWidgets(TimelineKind.values.length),
        reason: 'a filter you cannot see is a filter you do not have',
      );
    }
  });

  testWidgets('tapping a row no longer navigates away to a list', (
    tester,
  ) async {
    // Timeline is the app's only search surface, so it is the answer to "find
    // that thing I logged". It used to answer with the screen the entry lives
    // on — and for cost, odometer and income rows that was the vehicle page,
    // which opens on Economy, not even the tab holding the entry. You searched
    // twice. It now opens the entry's own sheet.
    //
    // Asserted as "does not navigate" because the sheet needs the entry
    // itself, and this harness stubs the timeline rather than the six entry
    // providers behind it. The regression being guarded is the push.
    final log = await pumpTimeline(
      tester,
      items: [item(kind: TimelineKind.cost)],
    );
    await tester.pumpAndSettle();
    final before = List<String>.from(log.visited);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(
      log.visited,
      before,
      reason: 'a row should open its entry, not push a screen',
    );
  });

  testWidgets('a desktop window gives the history more than reading width', (
    tester,
  ) async {
    await pumpTimeline(
      tester,
      items: [item()],
      surface: const Size(1500, 1000),
    );
    await tester.pumpAndSettle();

    expect(
      // Keyed: the filter chips above the log are a horizontal ListView too.
      tester.getSize(find.byKey(const Key('timeline-list'))).width,
      greaterThan(GarageBreakpoints.contentMaxWidth),
      reason:
          'a ledger row anchors its money on the right, so the reading cap '
          'leaves the rest of the window empty for nothing',
    );
  });

  // A car is a running total, and the timeline was the one screen showing
  // every entry without ever saying what they came to.
  group('what a month came to', () {
    testWidgets('spending shows against the month, signed as money out', (
      tester,
    ) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 62.40),
          item(entryId: 'e2', date: DateTime.utc(2026, 8, 2), amount: 3),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('−€65.40'), findsOneWidget);
    });

    testWidgets('a month a taxi paid for reads as money in', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 62.40),
          item(
            entryId: 'e2',
            kind: TimelineKind.income,
            date: DateTime.utc(2026, 8, 2),
            amount: 180,
            isIncome: true,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('+€117.60'), findsOneWidget);
    });

    testWidgets('each month is totalled on its own', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 100),
          item(entryId: 'e2', date: DateTime.utc(2026, 7, 24), amount: 40),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('−€100.00'), findsOneWidget);
      expect(find.text('−€40.00'), findsOneWidget);
    });

    testWidgets('a month of nothing but odometer readings shows no figure', (
      tester,
    ) async {
      await pumpTimeline(
        tester,
        items: [
          item(
            entryId: 'e1',
            kind: TimelineKind.odometer,
            date: DateTime.utc(2026, 8, 24),
            amount: null,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('€'), findsNothing);
    });
  });

  group('the line that closes the list', () {
    testWidgets('counts the transactions and says which way they went', (
      tester,
    ) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 100),
          item(entryId: 'e2', date: DateTime.utc(2026, 7, 24), amount: 40),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('2 transactions, spent €140.00'), findsOneWidget);
    });

    testWidgets('says received when the income won', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 40),
          item(
            entryId: 'e2',
            kind: TimelineKind.income,
            date: DateTime.utc(2026, 8, 2),
            amount: 100,
            isIncome: true,
          ),
        ],
      );
      await tester.pumpAndSettle();

      // With income in the list the figure is net, so the word is balance.
      // Net, so the word is balance, and signed like the month headers
      // above it: "balance €60" read the same either way.
      expect(find.text('2 transactions, balance +€60.00'), findsOneWidget);
    });

    testWidgets('one transaction is singular', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 40),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('1 transaction, spent €40.00'), findsOneWidget);
    });

    testWidgets('a reading is a row but not a transaction', (tester) async {
      await pumpTimeline(
        tester,
        items: [
          item(entryId: 'e1', date: DateTime.utc(2026, 8, 24), amount: 40),
          item(
            entryId: 'e2',
            kind: TimelineKind.odometer,
            date: DateTime.utc(2026, 8, 20),
            amount: null,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('1 transaction, spent €40.00'), findsOneWidget);
    });

    testWidgets('a list with no money in it closes without a line', (
      tester,
    ) async {
      await pumpTimeline(
        tester,
        items: [
          item(
            entryId: 'e1',
            kind: TimelineKind.odometer,
            date: DateTime.utc(2026, 8, 24),
            amount: null,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('transaction'), findsNothing);
    });
  });

  testWidgets('in Croatian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    // Croatian runs 20–30% longer than English, and a Row with an
    // unconstrained child overflows rather than sharing — which is how the
    // dashboard's own activity rows were broken.
    await pumpTimeline(
      tester,
      items: [
        item(kind: TimelineKind.fuel, amount: 62.5),
        item(entryId: 'e2', kind: TimelineKind.service, amount: 210.5),
        item(entryId: 'e3', kind: TimelineKind.trip, amount: null),
      ],
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 2400),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('in Italian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    // Croatian runs 20–30% longer than English, and a Row with an
    // unconstrained child overflows rather than sharing — which is how the
    // dashboard's own activity rows were broken.
    await pumpTimeline(
      tester,
      items: [
        item(kind: TimelineKind.fuel, amount: 62.5),
        item(entryId: 'e2', kind: TimelineKind.service, amount: 210.5),
        item(entryId: 'e3', kind: TimelineKind.trip, amount: null),
      ],
      locale: const Locale('it'),
      textScale: 1.5,
      surface: const Size(320, 2400),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
