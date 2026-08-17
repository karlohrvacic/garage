import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BundleCard(bundle: bundle)),
      ),
    ),
  );
}

/// The per-item trim control, which is an icon rather than a word: as a button
/// reading "Not this one" it sat a thumb's width from the item and read like a
/// decision about the service rather than about the suggestion.
Finder get trimButtons => find.byIcon(Icons.remove_circle_outline);

void main() {
  testWidgets('lists every item in the bundle', (tester) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    expect(trimButtons, findsNWidgets(3));
  });

  testWidgets('excluding an item removes it and moves the visit date', (
    tester,
  ) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    // The visit anchors to the earliest item, 1 August.
    expect(find.textContaining('Aug 1, 2026'), findsOneWidget);

    await tester.tap(trimButtons.first);
    await tester.pumpAndSettle();

    // Dropping the earliest item must re-anchor to the next one, not keep
    // quoting a date no item needs any more.
    expect(find.textContaining('Aug 1, 2026'), findsNothing);
    expect(find.textContaining('Aug 10, 2026'), findsOneWidget);
    expect(trimButtons, findsNWidgets(2));
  });

  testWidgets('excluding down to one item hides the card', (tester) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    await tester.tap(trimButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(trimButtons.first);
    await tester.pumpAndSettle();

    // One item is not a bundle, so there is nothing left to suggest.
    expect(trimButtons, findsNothing);
  });

  testWidgets('a trimmed item can be put back', (tester) async {
    // It could not be. Trimming mutated the bundle in place, so a mis-tap on a
    // bare button beside the row it removed was final until the card happened
    // to be rebuilt.
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    await tester.tap(trimButtons.first);
    await tester.pumpAndSettle();
    expect(trimButtons, findsNWidgets(2));

    await tester.tap(find.text('Put back'));
    await tester.pumpAndSettle();

    expect(trimButtons, findsNWidgets(3));
    expect(find.textContaining('Aug 1, 2026'), findsOneWidget);
  });

  testWidgets('says what trimming does, since it does less than it looks', (
    tester,
  ) async {
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('nothing is logged or cancelled'),
      findsOneWidget,
    );
  });

  testWidgets('offers to log the visit these items are for', (tester) async {
    // The card's whole point is that these are happening together, and it
    // said so and then left you to tick them off by hand on another screen.
    await pumpCard(tester, threeItemBundle());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bundle-log-visit')), findsOneWidget);
    expect(find.text('Log this visit'), findsOneWidget);
  });
}
