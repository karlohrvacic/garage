import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/incident.dart';
import 'package:garage/features/incidents/data/incident_repository.dart';
import 'package:garage/features/incidents/providers/incident_providers.dart';
import 'package:garage/features/incidents/widgets/incidents_card.dart';

import '../../support/pump_screen.dart';

class RecordingIncidents implements IncidentRepository {
  RecordingIncidents({this.stored = const []});

  List<Incident> stored;
  final List<String> calls = [];
  Incident? saved;

  @override
  Future<List<Incident>> forVehicle(String vehicleId) async => stored;

  @override
  Future<void> add(Incident incident) async {
    calls.add('add');
    saved = incident;
  }

  @override
  Future<void> update(Incident incident) async {
    calls.add('update:${incident.id}');
    saved = incident;
  }

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');
}

Incident reported({
  String id = 'i1',
  IncidentKind kind = IncidentKind.damage,
  String description = 'Scratched the rear bumper',
  DateTime? happenedOn,
  DateTime? resolvedOn,
  IncidentStatus status = IncidentStatus.open,
  double? amount,
}) {
  return Incident(
    id: id,
    vehicleId: 'v1',
    kind: kind,
    happenedOn: happenedOn ?? DateTime.utc(2026, 9, 10),
    description: description,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 9, 10),
    status: status,
    resolvedOn: resolvedOn,
    amount: amount,
  );
}

/// A Friday evening, local time, for the day a closed report is filed under.
final evening = DateTime(2026, 9, 18, 22, 15);

Future<void> pumpCard(
  WidgetTester tester,
  RecordingIncidents repository,
) async {
  await pumpScreen(
    tester,
    const Scaffold(
      body: SingleChildScrollView(child: IncidentsCard(vehicleId: 'v1')),
    ),
    surface: const Size(420, 1400),
    overrides: [
      incidentRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(() => evening),
    ],
  );
  await tester.pumpAndSettle();
}

/// Opens the row's menu, taps Close and answers the question it asks.
Future<void> closeAs(WidgetTester tester, String settledAs) async {
  await tester.tap(find.byKey(const Key('incident-menu-i1')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Close').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(settledAs).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a car with nothing reported says so', (tester) async {
    await pumpCard(tester, RecordingIncidents());

    expect(find.text('Nothing reported.'), findsOneWidget);
    expect(find.byKey(const Key('incident-add')), findsOneWidget);
  });

  testWidgets('a read that fails is said in the card', (tester) async {
    // Loading and a refused read used to look alike: a header and nothing,
    // and the cause never reached the failure log.
    await pumpCard(tester, _RefusingIncidents(reads: true));

    expect(find.textContaining('You do not have access'), findsOneWidget);
    expect(find.text('Nothing reported.'), findsNothing);
  });

  testWidgets('an open one shows its kind, status and amount', (tester) async {
    await pumpCard(
      tester,
      RecordingIncidents(
        stored: [reported(kind: IncidentKind.fine, amount: 40)],
      ),
    );

    expect(find.textContaining('Fine · '), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Scratched the rear bumper'), findsOneWidget);
    expect(find.textContaining('40'), findsOneWidget);
  });

  testWidgets('one with no amount does not print one', (tester) async {
    await pumpCard(tester, RecordingIncidents(stored: [reported()]));

    expect(find.textContaining('Damage · '), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
  });

  testWidgets('a private garage names no driver', (tester) async {
    // The line under the description is the fleet's; a household has no
    // log to read it off.
    await pumpCard(tester, RecordingIncidents(stored: [reported()]));

    expect(find.text('Scratched the rear bumper'), findsOneWidget);
    expect(find.byKey(const Key('driver-on-date')), findsNothing);
  });

  testWidgets('closing asks how it ended and records the day', (tester) async {
    final repository = RecordingIncidents(stored: [reported()]);
    await pumpCard(tester, repository);

    await closeAs(tester, 'Closed');

    expect(repository.calls, ['update:i1']);
    expect(repository.saved!.status, IncidentStatus.closed);
    // The evening's own day, not the UTC day it may already be elsewhere.
    expect(repository.saved!.resolvedOn, DateTime.utc(2026, 9, 18));
  });

  testWidgets('closing one the insurer has ends it as what was picked', (
    tester,
  ) async {
    // With the insurer is still open; paid is how that one usually ends.
    final repository = RecordingIncidents(
      stored: [reported(status: IncidentStatus.atInsurer)],
    );
    await pumpCard(tester, repository);

    await closeAs(tester, 'Paid');

    expect(repository.saved!.status, IncidentStatus.paid);
    expect(repository.saved!.resolvedOn, DateTime.utc(2026, 9, 18));
    expect(repository.saved!.isOpen, isFalse);
  });

  testWidgets('the question offers only the settled statuses', (tester) async {
    final repository = RecordingIncidents(stored: [reported()]);
    await pumpCard(tester, repository);

    await tester.tap(find.byKey(const Key('incident-menu-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();

    expect(find.text('Repaired'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('With the insurer'), findsNothing);
    // Put away without an answer: nothing written.
    Navigator.of(tester.element(find.text('Paid'))).pop();
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);
  });

  testWidgets('a settled one can be reopened', (tester) async {
    final repository = RecordingIncidents(
      stored: [
        reported(
          resolvedOn: DateTime.utc(2026, 9, 12),
          status: IncidentStatus.paid,
        ),
      ],
    );
    await pumpCard(tester, repository);

    await tester.tap(find.byKey(const Key('incident-menu-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen').last);
    await tester.pumpAndSettle();

    expect(repository.saved!.resolvedOn, isNull);
    expect(repository.saved!.status, IncidentStatus.open);
  });

  testWidgets('deleting asks first', (tester) async {
    final repository = RecordingIncidents(stored: [reported()]);
    await pumpCard(tester, repository);

    await tester.tap(find.byKey(const Key('incident-menu-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Its photos go with it'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('a delete the database refuses keeps the row and says why', (
    tester,
  ) async {
    // A driver deleting another driver's report: the policy says no, and
    // a row that quietly stays would look like a tap that did nothing.
    await pumpCard(tester, _RefusingIncidents(stored: [reported()]));

    await tester.tap(find.byKey(const Key('incident-menu-i1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Scratched the rear bumper'), findsOneWidget);
    expect(find.textContaining('You do not have access'), findsOneWidget);
  });
}

/// Refuses the writes, as a policy would, and the reads when asked to.
class _RefusingIncidents extends RecordingIncidents {
  _RefusingIncidents({super.stored, this.reads = false});

  final bool reads;

  @override
  Future<List<Incident>> forVehicle(String vehicleId) async {
    if (reads) {
      throw const AppFailure(kind: AppFailureKind.permission);
    }
    return stored;
  }

  @override
  Future<void> delete(String id) async {
    throw const AppFailure(kind: AppFailureKind.permission);
  }
}
