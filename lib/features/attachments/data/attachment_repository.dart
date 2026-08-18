import 'dart:typed_data';

import '../../../domain/entities/attachment.dart';

/// Receipts and documents kept with an entry. Screens depend on this, never on
/// Storage directly, so the backend can be faked in tests.
abstract interface class AttachmentRepository {
  Future<List<Attachment>> forEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  });

  /// The ids of every entry that carries at least one attachment.
  ///
  /// One query for the whole history rather than one per row: the timeline
  /// wants to mark which entries have a receipt, and asking per entry would be
  /// a request per visible row. RLS scopes it to the household already.
  Future<Set<String>> entryIdsWithAttachments();

  /// Uploads [bytes] and records the attachment against the entry.
  Future<Attachment> upload({
    required String vehicleId,
    required AttachmentEntryKind kind,
    required String entryId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  });

  /// A short-lived URL for viewing the file. The bucket is private, so nothing
  /// is readable without one.
  Future<Uri> viewUrl(Attachment attachment);

  /// Removes both the record and the stored file.
  Future<void> delete(Attachment attachment);
}
