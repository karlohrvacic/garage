import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/attachment.dart';
import '../data/attachment_repository.dart';
import '../data/supabase_attachment_repository.dart';

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  return SupabaseAttachmentRepository(ref.watch(supabaseClientProvider));
});

/// Which entry's attachments to fetch. A value type, so the family caches one
/// list per entry rather than refetching on every rebuild.
class AttachmentTarget {
  const AttachmentTarget({required this.kind, required this.entryId});

  final AttachmentEntryKind kind;
  final String entryId;

  @override
  bool operator ==(Object other) =>
      other is AttachmentTarget &&
      other.kind == kind &&
      other.entryId == entryId;

  @override
  int get hashCode => Object.hash(kind, entryId);

  @override
  String toString() => 'AttachmentTarget(${kind.key}, $entryId)';
}

/// What is attached to one entry, oldest first.
final entryAttachmentsProvider =
    FutureProvider.family<List<Attachment>, AttachmentTarget>((
      ref,
      target,
    ) async {
      return ref
          .watch(attachmentRepositoryProvider)
          .forEntry(kind: target.kind, entryId: target.entryId);
    });

/// Which entries carry at least one attachment, for the whole history.
///
/// One query rather than one per row: the timeline marks entries that have a
/// receipt, and asking per entry would be a request for every visible row.
final entriesWithAttachmentsProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(attachmentRepositoryProvider).entryIdsWithAttachments();
});
