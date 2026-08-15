import 'dart:typed_data';

import '../../../domain/entities/attachment.dart';

/// Receipts and documents kept with an entry. Screens depend on this, never on
/// Storage directly, so the backend can be faked in tests.
abstract interface class AttachmentRepository {
  Future<List<Attachment>> forEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  });

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
