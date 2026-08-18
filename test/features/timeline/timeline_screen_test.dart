import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
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
  );
}

Future<NavigationLog> pumpTimeline(
  WidgetTester tester, {
  List<TimelineItem> items = const [],
  Size surface = const Size(400, 900),
  double textScale = 1,
  Set<String> withAttachments = const {},
}) {
  return pumpScreen(
    tester,
    const TimelineScreen(),
    initialLocation: '/timeline',
    surface: surface,
    textScale: textScale,
    overrides: [
      timelineProvider.overrideWith((ref) async => items),
      entriesWithAttachmentsProvider.overrideWith(
        (ref) async => withAttachments,
      ),
      vehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
    ],
  );
}

void main() {
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
    expect(find.textContaining('€62'), findsOneWidget);
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

      expect(inLog('Trip log'), findsOneWidget);

      // The kinds live behind the search field's filter button now: six chips
      // permanently above the list cost two or three rows on a phone, all of
      // it spent on a filter almost nobody has switched on.
      await tester.tap(find.byKey(const Key('timeline-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timeline-kind-fuel')));
      await tester.pumpAndSettle();
      expect(inLog('Trip log'), findsNothing);
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
      expect(inLog('Trip log'), findsNothing);
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
}
