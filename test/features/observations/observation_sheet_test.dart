import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/observation.dart';
import 'package:garage/features/observations/providers/observation_providers.dart';
import 'package:garage/features/observations/widgets/observation_sheet.dart';

import '../../support/pump_screen.dart';
import 'observations_card_test.dart' show RecordingObservations, seen;
import '../../support/fake_attachments.dart';
import 'package:garage/domain/entities/attachment.dart';

/// Opens the sheet from a bare button, so the test is about the form rather
/// than about whatever screen happened to launch it.
Future<void> pumpSheet(
  WidgetTester tester,
  RecordingObservations repository, {
  Observation? existing,
  String? tripId,
  FakeAttachmentRepository? attachments,
  XFile? pickedFile,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(420, 1400),
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showObservationSheet(
            context,
            vehicleId: 'v1',
            existing: existing,
            tripId: tripId,
          ),
          child: const Text('open'),
        ),
      ),
    ),
    surface: surface,
    locale: locale,
    textScale: textScale,
    attachments: attachments,
    overrides: [
      observationRepositoryProvider.overrideWithValue(repository),
      if (pickedFile != null)
        filePickerProvider.overrideWithValue(() async => pickedFile),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a note is saved with today as the day it was noticed', (
    tester,
  ) async {
    final repository = RecordingObservations();
    await pumpSheet(tester, repository);

    await tester.enterText(
      find.byKey(const Key('observation-note')),
      'Vibration since the pothole on Ilica',
    );
    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['add']);
    expect(repository.saved!.note, 'Vibration since the pothole on Ilica');
    expect(repository.saved!.isOpen, isTrue);
    expect(repository.saved!.id, isNotEmpty);
  });

  testWidgets('an empty note is refused rather than saved blank', (
    tester,
  ) async {
    // A problem with no description is a row nobody can act on.
    final repository = RecordingObservations();
    await pumpSheet(tester, repository);

    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.byKey(const Key('observation-save')), findsOneWidget);
  });

  testWidgets('whitespace alone is an empty note', (tester) async {
    final repository = RecordingObservations();
    await pumpSheet(tester, repository);

    await tester.enterText(find.byKey(const Key('observation-note')), '   ');
    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
  });

  testWidgets('an odometer reading rides along when given', (tester) async {
    final repository = RecordingObservations();
    await pumpSheet(tester, repository);

    await tester.enterText(
      find.byKey(const Key('observation-note')),
      'Warning light',
    );
    await tester.enterText(
      find.byKey(const Key('observation-odometer')),
      '142850',
    );
    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.saved!.odometerKm, 142850);
  });

  testWidgets('one noticed on a drive remembers which drive', (tester) async {
    // This is the whole of the "driving events" idea: an observation that
    // points at a journey.
    final repository = RecordingObservations();
    await pumpSheet(tester, repository, tripId: 't7');

    await tester.enterText(
      find.byKey(const Key('observation-note')),
      'Braked hard for a deer',
    );
    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.saved!.tripId, 't7');
    expect(repository.saved!.happenedOnATrip, isTrue);
  });

  testWidgets('editing updates the row rather than adding a second', (
    tester,
  ) async {
    final repository = RecordingObservations();
    await pumpSheet(tester, repository, existing: seen(note: 'Old wording'));

    await tester.enterText(
      find.byKey(const Key('observation-note')),
      'Better wording',
    );
    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['update:o1']);
    expect(repository.saved!.note, 'Better wording');
    expect(repository.saved!.id, 'o1');
  });

  testWidgets('a photo can be attached before the note is written', (
    tester,
  ) async {
    // The order these actually happen in: the picture is taken at the car and
    // the sentence is typed afterwards. The id is minted before the first
    // keystroke, which is what makes it possible (decision 90).
    final repository = RecordingObservations();
    await pumpSheet(
      tester,
      repository,
      attachments: FakeAttachmentRepository(),
    );

    expect(find.byTooltip('Attach a receipt or document'), findsOneWidget);
  });

  testWidgets('a photo taken is not thrown away without asking', (
    tester,
  ) async {
    // Nothing typed, and still something that cannot be taken again once the
    // rattle has stopped: closing a new note deletes its photo (decision 90).
    // The guard read the uploads as they stood at its last build, and taking
    // the photo did not rebuild it.
    await pumpSheet(
      tester,
      RecordingObservations(),
      attachments: FakeAttachmentRepository(),
      pickedFile: XFile.fromData(
        Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        name: 'crack.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    await tester.tap(find.byTooltip('Attach a receipt or document'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).last).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Discard what you typed?'), findsOneWidget);
  });

  testWidgets('a note that was never saved takes its photo down with it', (
    tester,
  ) async {
    // The file would otherwise hang off a row nobody created, and nothing
    // lists or sweeps those (decision 90).
    final attachments = FakeAttachmentRepository([_photo])
      ..matchAnyEntry = true;
    await pumpSheet(tester, RecordingObservations(), attachments: attachments);

    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();

    expect(attachments.calls, contains('delete:a1'));
    expect(attachments.stored, isEmpty);
  });

  testWidgets('a saved note keeps its photo', (tester) async {
    final attachments = FakeAttachmentRepository([_photo])
      ..matchAnyEntry = true;
    final repository = RecordingObservations();
    await pumpSheet(tester, repository, attachments: attachments);

    await tester.enterText(
      find.byKey(const Key('observation-note')),
      'Crack in the windscreen',
    );
    await tester.tap(find.byKey(const Key('observation-save')));
    await tester.pumpAndSettle();

    expect(repository.calls, ['add']);
    expect(
      attachments.stored,
      isNotEmpty,
      reason: 'nothing is cleaned up after a note that was actually saved',
    );
  });
  testWidgets('in Croatian on a narrow phone the sheet lays out', (
    tester,
  ) async {
    // The hint under the note field is a full sentence in Croatian and had
    // never been rendered. An overflow throws; the assertion is that none did.
    await pumpSheet(
      tester,
      RecordingObservations(),
      attachments: FakeAttachmentRepository(),
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 2400),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('in Italian on a narrow phone the sheet lays out', (
    tester,
  ) async {
    // The hint under the note field is a full sentence in Croatian and had
    // never been rendered. An overflow throws; the assertion is that none did.
    await pumpSheet(
      tester,
      RecordingObservations(),
      attachments: FakeAttachmentRepository(),
      locale: const Locale('it'),
      textScale: 1.5,
      surface: const Size(320, 2400),
    );

    expect(tester.takeException(), isNull);
  });
}

/// A photo already attached to whatever id the sheet minted for itself.
final _photo = Attachment(
  id: 'a1',
  vehicleId: 'v1',
  entryKind: AttachmentEntryKind.observation,
  entryId: 'minted-inside-the-sheet',
  storagePath: 'v1/a1-crack.jpg',
  fileName: 'crack.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 512,
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 9, 1),
);
