import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';

/// `attachments.entry_id` carries no foreign key (decision 90), so nothing in
/// the database takes a receipt away when its entry goes. The app has to, and
/// `PRIVACY.md` promises it does.
///
/// The failure is silent in both directions: the entry disappears, the file
/// stays in a private bucket, and nobody sees either. So the delete sites are
/// checked instead of trusted.
void main() {
  /// How each attachment-bearing entry kind is deleted, as it appears in a
  /// screen, a sheet or a controller. The data layer is excluded: a repository
  /// deletes one row and knows nothing about receipts.
  ///
  /// **Every kind in `AttachmentEntryKind` belongs here.** Observations were
  /// added to that enum and missed here on the same day, which is the whole
  /// argument for the list existing.
  const deleteCalls = {
    'fuelRepositoryProvider).delete(',
    'costRepositoryProvider).delete(',
    'deleteServiceEntry(',
    'documentRepositoryProvider).delete(',
    'observationRepositoryProvider).delete(',
  };

  /// Which kind each delete expression belongs to, so a kind added to
  /// `AttachmentEntryKind` without a delete pattern here fails loudly rather
  /// than being scanned for nothing.
  const kindOf = {
    'fuelRepositoryProvider).delete(': AttachmentEntryKind.fuel,
    'costRepositoryProvider).delete(': AttachmentEntryKind.cost,
    'deleteServiceEntry(': AttachmentEntryKind.service,
    'documentRepositoryProvider).delete(': AttachmentEntryKind.document,
    'observationRepositoryProvider).delete(': AttachmentEntryKind.observation,
  };

  test('every attachment kind has a delete this test knows how to find', () {
    expect(kindOf.values.toSet(), AttachmentEntryKind.values.toSet());
    expect(kindOf.keys.toSet(), deleteCalls);
  });

  test('every entry deletion takes its attachments with it', () {
    final offenders = <String>[];

    for (final file in Directory('lib/features').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) {
        continue;
      }
      if (file.path.contains('/data/')) {
        continue;
      }
      final source = file.readAsStringSync();
      final deletes = deleteCalls.where(source.contains);
      if (deletes.isEmpty || source.contains('sweepAttachments')) {
        continue;
      }
      offenders.add('${file.path}: ${deletes.join(', ')}');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these delete an entry that can carry attachments without sweeping '
          'them — call sweepAttachments(ref.read(attachmentRepositoryProvider), '
          '…) after the entry is gone',
    );
  });
}
