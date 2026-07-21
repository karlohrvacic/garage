import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/dashboard/widgets/bundle_card.dart';
import 'package:garage/l10n/app_localizations.dart';

ReminderProjection due(String id, DateTime date) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: 'v1',
    serviceTypeKey: 'service_$id',
    projectedDueDate: date,
    state: ReminderState.upcoming,
  );
}

MaintenanceBundle threeItemBundle() {
  return BundlingEngine.bundle(
    projections: [
      due('a', DateTime(2026, 8, 1)),
      due('b', DateTime(2026, 8, 10)),
      due('c', DateTime(2026, 8, 18)),
    ],
    today: DateTime(2026, 7, 20),
  ).single;
}

Future<void> pumpCard(WidgetTester tester, MaintenanceBundle bundle) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: BundleCard(bundle: bundle)),
    ),
  );
}

void main() {
  testWidgets('lists every item in the bundle', (tester) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    expect(find.textContaining('Not this one'), findsNWidgets(3));
  });

  testWidgets('excluding an item removes it and moves the visit date',
      (tester) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    // The visit anchors to the earliest item, 1 August.
    expect(find.textContaining('Aug 1, 2026'), findsOneWidget);

    await tester.tap(find.textContaining('Not this one').first);
    await tester.pumpAndSettle();

    // Dropping the earliest item must re-anchor to the next one, not keep
    // quoting a date no item needs any more.
    expect(find.textContaining('Aug 1, 2026'), findsNothing);
    expect(find.textContaining('Aug 10, 2026'), findsOneWidget);
    expect(find.textContaining('Not this one'), findsNWidgets(2));
  });

  testWidgets('excluding down to one item hides the card', (tester) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Not this one').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Not this one').first);
    await tester.pumpAndSettle();

    // One item is not a bundle, so there is nothing left to suggest.
    expect(find.textContaining('Not this one'), findsNothing);
  });
}
