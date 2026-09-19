import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/domain/entities/incident.dart';
import 'package:garage/features/incidents/providers/incident_providers.dart';
import 'package:garage/features/incidents/widgets/incident_sheet.dart';

import '../../support/fake_attachments.dart';
import '../../support/pump_screen.dart';
import 'incidents_card_test.dart' show RecordingIncidents, reported;

/// A repository whose writes are refused, as the policy refuses a driver
/// editing somebody else's report.
class RefusingIncidents extends RecordingIncidents {
  @override
  Future<void> update(Incident incident) async {
    calls.add('update:${incident.id}');
    throw const AppFailure(kind: AppFailureKind.permission);
  }
}

/// One in the morning, local time: already the previous day in UTC west of
/// Greenwich, and still yesterday's UTC instant east of it.
final smallHours = DateTime(2026, 9, 19, 1, 0);

Future<void> pumpSheet(
  WidgetTester tester,
  RecordingIncidents repository, {
  Incident? existing,
  FakeAttachmentRepository? attachments,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(420, 1600),
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showIncidentSheet(context, vehicleId: 'v1', existing: existing),
          child: const Text('open'),
        ),
      ),
    ),
    surface: surface,
    locale: locale,
    textScale: textScale,
    attachments: attachments ?? FakeAttachmentRepository(),
    overrides: [
      incidentRepositoryProvider.overrideWithValue(repository),
      todayProvider.overrideWithValue(smallHours),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a report is saved with its kind and what happened', (
    tester,
  ) async {
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository);

    await tester.tap(find.byKey(const Key('incident-kind-fine')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('incident-description')),
      'Parking fine, Vukovarska',
    );
    await tester.enterText(find.byKey(const Key('incident-amount')), '40');
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['add']);
    expect(repository.saved!.kind, IncidentKind.fine);
    expect(repository.saved!.description, 'Parking fine, Vukovarska');
    expect(repository.saved!.amount, 40);
    expect(repository.saved!.isOpen, isTrue);
    expect(repository.saved!.id, isNotEmpty);
  });

  testWidgets('a report is filed under the day it is, where it is', (
    tester,
  ) async {
    // One in the morning in Croatia is still yesterday in UTC: the UTC
    // instant's date would file the report under the wrong day, and closing
    // it that night would then fail the check that it was settled after it
    // happened.
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository);

    await tester.enterText(
      find.byKey(const Key('incident-description')),
      'Clipped the mirror leaving the depot',
    );
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.saved!.happenedOn, DateTime.utc(2026, 9, 19));
    expect(repository.saved!.happenedOn.isUtc, isTrue);
  });

  testWidgets('a report with no amount is saved without one', (tester) async {
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository);

    await tester.enterText(
      find.byKey(const Key('incident-description')),
      'Rattle from the rear axle',
    );
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['add']);
    expect(repository.saved!.amount, isNull);
    expect(repository.saved!.odometerKm, isNull);
  });

  testWidgets('nothing described is refused rather than saved blank', (
    tester,
  ) async {
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository);

    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.byKey(const Key('incident-save')), findsOneWidget);
  });

  testWidgets('editing changes the status and updates the row', (tester) async {
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository, existing: reported());

    await tester.tap(find.byKey(const Key('incident-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('With the insurer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['update:i1']);
    expect(repository.saved!.status, IncidentStatus.atInsurer);
    // Handing it to the insurer is not settling it: only closing writes
    // the day, from the card's menu.
    expect(repository.saved!.isOpen, isTrue);
  });

  testWidgets('a new report offers no status: it is open by definition', (
    tester,
  ) async {
    await pumpSheet(tester, RecordingIncidents());

    expect(find.byKey(const Key('incident-status')), findsNothing);
  });

  testWidgets('an open report is offered only the open statuses', (
    tester,
  ) async {
    // Settling is the card's act, which writes the day with the word; a
    // field that offered "Paid" would settle it without one.
    await pumpSheet(tester, RecordingIncidents(), existing: reported());

    await tester.tap(find.byKey(const Key('incident-status')));
    await tester.pumpAndSettle();

    expect(find.text('With the insurer'), findsWidgets);
    expect(find.text('Paid'), findsNothing);
    expect(find.text('Repaired'), findsNothing);
    expect(find.text('Closed'), findsNothing);
  });

  testWidgets('a settled report shows its status as words and keeps it', (
    tester,
  ) async {
    final repository = RecordingIncidents();
    await pumpSheet(
      tester,
      repository,
      existing: reported(
        status: IncidentStatus.paid,
        resolvedOn: DateTime.utc(2026, 9, 12),
        amount: 40,
      ),
    );

    expect(find.byKey(const Key('incident-status')), findsNothing);
    expect(find.text('Paid'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('incident-description')),
      'Parking fine, paid from petty cash',
    );
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.saved!.status, IncidentStatus.paid);
    expect(repository.saved!.resolvedOn, DateTime.utc(2026, 9, 12));
    expect(repository.saved!.isOpen, isFalse);
  });

  testWidgets('emptying the amount clears it', (tester) async {
    // A fine that was waived is not a fine of forty euros.
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository, existing: reported(amount: 40));

    await tester.enterText(find.byKey(const Key('incident-amount')), '');
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['update:i1']);
    expect(repository.saved!.amount, isNull);
  });

  testWidgets('an amount that is not a number is refused, not dropped', (
    tester,
  ) async {
    final repository = RecordingIncidents();
    await pumpSheet(tester, repository, existing: reported(amount: 40));

    await tester.enterText(find.byKey(const Key('incident-amount')), 'forty');
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.textContaining('not accepted'), findsOneWidget);
  });

  testWidgets('an edit the database refuses keeps the sheet open and says '
      'why', (tester) async {
    final repository = RefusingIncidents();
    await pumpSheet(tester, repository, existing: reported());

    await tester.enterText(
      find.byKey(const Key('incident-description')),
      'Somebody else\'s dent, reworded',
    );
    await tester.tap(find.byKey(const Key('incident-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['update:i1']);
    expect(find.byKey(const Key('incident-save')), findsOneWidget);
    expect(find.textContaining('You do not have access'), findsOneWidget);
  });

  testWidgets('a photo can be attached before the report is written', (
    tester,
  ) async {
    await pumpSheet(tester, RecordingIncidents());

    expect(find.byTooltip('Attach a receipt or document'), findsOneWidget);
  });

  testWidgets('a report that was never saved takes its photo down with it', (
    tester,
  ) async {
    // The file would otherwise hang off a row nobody created (decision 90).
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.incident, entryId: 'minted-inside'),
    ])..matchAnyEntry = true;
    await pumpSheet(tester, RecordingIncidents(), attachments: attachments);

    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();

    expect(attachments.calls, contains('delete:a1'));
    expect(attachments.stored, isEmpty);
  });

  testWidgets('in Croatian on a narrow phone the sheet lays out', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      RecordingIncidents(),
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 2400),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('and so does an edit, with the status field', (tester) async {
    await pumpSheet(
      tester,
      RecordingIncidents(),
      existing: reported(status: IncidentStatus.atInsurer, amount: 1250),
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 2400),
    );

    expect(tester.takeException(), isNull);
  });
}
