import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/domain/entities/incident.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/incidents/providers/incident_providers.dart';

import '../../support/fake_attachments.dart';
import 'incidents_card_test.dart' show RecordingIncidents, reported;

void main() {
  test('deleting a report takes its photos with it', () async {
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.incident, entryId: 'i1'),
    ]);
    final container = ProviderContainer(
      overrides: [
        incidentRepositoryProvider.overrideWithValue(
          RecordingIncidents(stored: [reported()]),
        ),
        attachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(incidentControllerProvider.notifier)
        .delete(reported());

    expect(ok, isTrue);
    expect(attachments.stored, isEmpty);
    expect(attachments.calls, contains('deleteForEntry:incident:i1'));
  });

  test('a sweep that fails still reports the incident as deleted', () async {
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.incident, entryId: 'i1'),
    ])..failSweep = true;
    final repository = RecordingIncidents(stored: [reported()]);
    final container = ProviderContainer(
      overrides: [
        incidentRepositoryProvider.overrideWithValue(repository),
        attachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container
          .read(incidentControllerProvider.notifier)
          .delete(reported()),
      isTrue,
    );
    expect(repository.calls, contains('delete:i1'));
  });

  test('a delete the database refuses keeps the photos and says why', () async {
    // The row is still there, so its photos must be too, and the failure is
    // what the card shows.
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.incident, entryId: 'i1'),
    ]);
    final container = ProviderContainer(
      overrides: [
        incidentRepositoryProvider.overrideWithValue(_RefusingDelete()),
        attachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(incidentControllerProvider.notifier)
        .delete(reported());

    expect(ok, isFalse);
    expect(attachments.stored, hasLength(1));
    expect(
      container.read(incidentControllerProvider).error,
      isA<AppFailure>().having(
        (it) => it.kind,
        'kind',
        AppFailureKind.permission,
      ),
    );
  });

  test('closing writes the status picked and the clock\'s day; reopening '
      'clears both', () async {
    final repository = RecordingIncidents(stored: [reported()]);
    final container = ProviderContainer(
      overrides: [
        incidentRepositoryProvider.overrideWithValue(repository),
        // Late on the 14th, local time: the day the admin saw, whatever
        // that is in UTC.
        clockProvider.overrideWithValue(() => DateTime(2026, 9, 14, 23, 30)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(incidentControllerProvider.notifier);

    await controller.close(
      reported(status: IncidentStatus.atInsurer),
      status: IncidentStatus.paid,
    );
    expect(repository.saved!.resolvedOn, DateTime.utc(2026, 9, 14));
    expect(repository.saved!.status, IncidentStatus.paid);
    expect(repository.saved!.isOpen, isFalse);

    await controller.reopen(repository.saved!);
    expect(repository.saved!.resolvedOn, isNull);
    expect(repository.saved!.status, IncidentStatus.open);
    expect(repository.saved!.isOpen, isTrue);
  });
}

class _RefusingDelete extends RecordingIncidents {
  @override
  Future<void> delete(String id) async {
    throw const AppFailure(kind: AppFailureKind.permission);
  }
}
