import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';

import '../../support/fake_attachments.dart';

export '../../support/fake_attachments.dart' show FakeAttachmentRepository;

ProviderContainer containerWith(FakeAttachmentRepository fake) {
  final container = ProviderContainer(
    overrides: [attachmentRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an entry with nothing attached reads as empty', () async {
    final container = containerWith(FakeAttachmentRepository());

    final list = await container.read(
      entryAttachmentsProvider(
        const AttachmentTarget(kind: AttachmentEntryKind.fuel, entryId: 'f1'),
      ).future,
    );

    expect(list, isEmpty);
  });

  test('only the asked-for entry comes back', () async {
    final container = containerWith(
      FakeAttachmentRepository([
        attachment(id: 'a1'),
        attachment(id: 'a2', entryId: 'f2'),
        attachment(id: 'a3', kind: AttachmentEntryKind.service, entryId: 'f1'),
      ]),
    );

    final list = await container.read(
      entryAttachmentsProvider(
        const AttachmentTarget(kind: AttachmentEntryKind.fuel, entryId: 'f1'),
      ).future,
    );

    expect(list.map((a) => a.id), ['a1']);
  });

  test('two targets are separate cache entries', () async {
    final fake = FakeAttachmentRepository([attachment()]);
    final container = containerWith(fake);

    await container.read(
      entryAttachmentsProvider(
        const AttachmentTarget(kind: AttachmentEntryKind.fuel, entryId: 'f1'),
      ).future,
    );
    await container.read(
      entryAttachmentsProvider(
        const AttachmentTarget(kind: AttachmentEntryKind.cost, entryId: 'c1'),
      ).future,
    );

    expect(fake.calls, ['forEntry:fuel:f1', 'forEntry:cost:c1']);
  });

  test('a target compares by value, so the family caches by identity', () {
    const a = AttachmentTarget(kind: AttachmentEntryKind.fuel, entryId: 'f1');
    const b = AttachmentTarget(kind: AttachmentEntryKind.fuel, entryId: 'f1');
    const c = AttachmentTarget(kind: AttachmentEntryKind.cost, entryId: 'f1');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });

  test('an upload lands in the next read of that entry', () async {
    final fake = FakeAttachmentRepository();
    final container = containerWith(fake);
    const target = AttachmentTarget(
      kind: AttachmentEntryKind.fuel,
      entryId: 'f1',
    );

    expect(
      await container.read(entryAttachmentsProvider(target).future),
      isEmpty,
    );

    await fake.upload(
      vehicleId: 'v1',
      kind: AttachmentEntryKind.fuel,
      entryId: 'f1',
      fileName: 'receipt.jpg',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    container.invalidate(entryAttachmentsProvider(target));

    expect(
      await container.read(entryAttachmentsProvider(target).future),
      hasLength(1),
    );
  });
}
