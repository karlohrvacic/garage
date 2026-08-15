import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
import 'package:garage/features/timeline/screens/timeline_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

TimelineItem item({
  TimelineKind kind = TimelineKind.fuel,
  DateTime? date,
  double? amount = 62,
  String vehicleId = 'v1',
  List<String> serviceTypeKeys = const [],
  String? costCategory,
  String createdBy = 'u1',
}) {
  return TimelineItem(
    kind: kind,
    date: date ?? DateTime.utc(2026, 7, 24),
    vehicleId: vehicleId,
    amount: amount,
    createdBy: createdBy,
    serviceTypeKeys: serviceTypeKeys,
    costCategory: costCategory,
    odometerKm: 51140,
  );
}

Future<NavigationLog> pumpTimeline(
  WidgetTester tester, {
  List<TimelineItem> items = const [],
}) {
  return pumpScreen(
    tester,
    const TimelineScreen(),
    initialLocation: '/timeline',
    overrides: [
      timelineProvider.overrideWith((ref) async => items),
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
}
