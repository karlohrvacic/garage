import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/domain/entities/observation.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/observations/providers/observation_providers.dart';

import '../../support/fake_attachments.dart';
import 'observations_card_test.dart' show RecordingObservations;

final noted = Observation(
  id: 'o1',
  vehicleId: 'v1',
  noticedOn: DateTime.utc(2026, 9, 1),
  note: 'Crack in the windscreen',
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 9, 1),
);

Attachment photo({String entryId = 'o1'}) => Attachment(
  id: 'a1',
  vehicleId: 'v1',
  entryKind: AttachmentEntryKind.observation,
  entryId: entryId,
  storagePath: 'v1/a1-crack.jpg',
  fileName: 'crack.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 512,
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 9, 1),
);

void main() {
  test('deleting a note takes its photo with it', () async {
    // Observations became the fifth thing that can carry an attachment on the
    // same day the sweep was written for the other four, and were missed. The
    // photo would have stayed in a private bucket with nothing pointing at it.
    final attachments = FakeAttachmentRepository([photo()]);
    final container = ProviderContainer(
      overrides: [
        observationRepositoryProvider.overrideWithValue(
          RecordingObservations(stored: [noted]),
        ),
        attachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(observationControllerProvider.notifier)
        .delete(noted);

    expect(ok, isTrue);
    expect(attachments.stored, isEmpty);
    expect(attachments.calls, contains('deleteForEntry:observation:o1'));
  });

  test('a photo on another note is left alone', () async {
    final attachments = FakeAttachmentRepository([photo(entryId: 'o2')]);
    final container = ProviderContainer(
      overrides: [
        observationRepositoryProvider.overrideWithValue(
          RecordingObservations(stored: [noted]),
        ),
        attachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);

    await container.read(observationControllerProvider.notifier).delete(noted);

    expect(attachments.stored, hasLength(1));
  });

  test('a sweep that fails still reports the note as deleted', () async {
    // The note is already gone. Reporting failure would send somebody back to
    // delete it again.
    final attachments = FakeAttachmentRepository([photo()])..failSweep = true;
    final repository = RecordingObservations(stored: [noted]);
    final container = ProviderContainer(
      overrides: [
        observationRepositoryProvider.overrideWithValue(repository),
        attachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(observationControllerProvider.notifier)
        .delete(noted);

    expect(ok, isTrue);
    expect(repository.calls, contains('delete:o1'));
  });
}
