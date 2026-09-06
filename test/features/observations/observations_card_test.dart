import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/observation.dart';
import 'package:garage/features/observations/data/observation_repository.dart';
import 'package:garage/features/observations/providers/observation_providers.dart';
import 'package:garage/features/observations/widgets/observations_card.dart';

import '../../support/pump_screen.dart';

class RecordingObservations implements ObservationRepository {
  RecordingObservations({this.stored = const []});

  List<Observation> stored;
  final List<String> calls = [];
  Observation? saved;

  @override
  Future<List<Observation>> forVehicle(String vehicleId) async => stored;

  @override
  Future<void> add(Observation observation) async {
    calls.add('add');
    saved = observation;
  }

  @override
  Future<void> update(Observation observation) async {
    calls.add('update:${observation.id}');
    saved = observation;
  }

  @override
  Future<void> delete(String id) async => calls.add('delete:$id');
}

Observation seen({
  String id = 'o1',
  String note = 'Rattles when cold',
  DateTime? noticedOn,
  DateTime? resolvedOn,
  String? addressedBy,
  int? odometerKm,
}) {
  return Observation(
    id: id,
    vehicleId: 'v1',
    noticedOn:
        noticedOn ?? DateTime.now().toUtc().subtract(const Duration(days: 5)),
    note: note,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 9, 1),
    resolvedOn: resolvedOn,
    addressedBy: addressedBy,
    odometerKm: odometerKm,
  );
}

Future<void> pumpCard(
  WidgetTester tester,
  RecordingObservations repository,
) async {
  await pumpScreen(
    tester,
    const Scaffold(
      body: SingleChildScrollView(child: ObservationsCard(vehicleId: 'v1')),
    ),
    surface: const Size(420, 1400),
    overrides: [observationRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a car with nothing wrong says what belongs here', (
    tester,
  ) async {
    await pumpCard(tester, RecordingObservations());

    expect(find.textContaining('Nothing noted'), findsOneWidget);
    expect(find.byKey(const Key('observation-add')), findsOneWidget);
  });

  testWidgets('an open problem shows how long it has been going on', (
    tester,
  ) async {
    await pumpCard(
      tester,
      RecordingObservations(stored: [seen(note: 'Rattles when cold')]),
    );

    expect(find.text('Rattles when cold'), findsOneWidget);
    expect(find.text('Not sorted'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
  });

  testWidgets('work done without the noise stopping says exactly that', (
    tester,
  ) async {
    // The line the whole two-field split exists for.
    await pumpCard(
      tester,
      RecordingObservations(stored: [seen(addressedBy: 's1')]),
    );

    expect(find.text('Still there after work'), findsOneWidget);
    expect(
      find.text('Work was done and you have not said it stopped.'),
      findsOneWidget,
    );
  });

  testWidgets('a settled one reads as settled, with its date', (tester) async {
    await pumpCard(
      tester,
      RecordingObservations(
        stored: [seen(resolvedOn: DateTime.utc(2026, 9, 3))],
      ),
    );

    expect(find.text('Sorted'), findsOneWidget);
    expect(find.textContaining('Stopped'), findsOneWidget);
  });

  testWidgets('the oldest unsettled complaint leads', (tester) async {
    // What you want to mention at the counter is the thing you have lived
    // with, not the thing you noticed yesterday.
    await pumpCard(
      tester,
      RecordingObservations(
        stored: [
          seen(
            id: 'new',
            note: 'Noticed yesterday',
            noticedOn: DateTime.now().toUtc().subtract(const Duration(days: 1)),
          ),
          seen(
            id: 'old',
            note: 'Lived with for months',
            noticedOn: DateTime.now().toUtc().subtract(
              const Duration(days: 90),
            ),
          ),
        ],
      ),
    );

    final old = tester.getTopLeft(find.text('Lived with for months'));
    final recent = tester.getTopLeft(find.text('Noticed yesterday'));
    expect(old.dy, lessThan(recent.dy));
  });

  testWidgets('saying it stopped records the date rather than deleting it', (
    tester,
  ) async {
    // A problem that went away is history worth keeping: it is the answer to
    // "has this happened before" at the next service.
    final repository = RecordingObservations(stored: [seen()]);
    await pumpCard(tester, repository);

    await tester.tap(find.byKey(const Key('observation-menu-o1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('It has stopped').last);
    await tester.pumpAndSettle();

    expect(repository.calls, ['update:o1']);
    expect(repository.saved!.resolvedOn, isNotNull);
    expect(repository.saved!.note, 'Rattles when cold');
  });

  testWidgets('a noise that came back reopens the same row', (tester) async {
    final repository = RecordingObservations(
      stored: [seen(resolvedOn: DateTime.utc(2026, 9, 3))],
    );
    await pumpCard(tester, repository);

    await tester.tap(find.byKey(const Key('observation-menu-o1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('It is back').last);
    await tester.pumpAndSettle();

    expect(repository.saved!.resolvedOn, isNull);
    expect(repository.calls, [
      'update:o1',
    ], reason: 'the same complaint, not a second one');
  });

  testWidgets('deleting asks first', (tester) async {
    final repository = RecordingObservations(stored: [seen()]);
    await pumpCard(tester, repository);

    await tester.tap(find.byKey(const Key('observation-menu-o1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The record of noticing it goes'),
      findsOneWidget,
    );
    expect(repository.calls, isEmpty);
  });
}
