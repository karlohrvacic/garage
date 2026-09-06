import 'dart:typed_data';

import '../../domain/entities/attachment.dart';
import '../../features/attachments/data/attachment_repository.dart';
import '../errors/app_failure.dart';
import 'pending_write.dart';
import 'queued_files.dart';
import 'write_queue.dart';

/// Thrown when a photo could not be sent but has been kept on the phone.
///
/// A distinct type rather than a failure, because it is not one: the file is
/// safe and will go up on its own. The widget that catches it says so instead
/// of showing an error for something that did not go wrong.
class AttachmentQueued implements Exception {
  const AttachmentQueued();
}

/// Keeps a photo whose upload the network could not carry.
///
/// Unlike an entry, an upload has a return value the caller uses, so this
/// cannot quietly succeed. It throws [AttachmentQueued], which says something
/// true and different from "that failed".
class QueueingAttachmentRepository implements AttachmentRepository {
  QueueingAttachmentRepository({
    required this.inner,
    required this.queue,
    required this.now,
    this.files = const PlatformQueuedFileStore(),
  });

  final AttachmentRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final QueuedFileStore files;

  @override
  Future<Attachment> upload({
    required String vehicleId,
    required AttachmentEntryKind kind,
    required String entryId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      return await inner.upload(
        vehicleId: vehicleId,
        kind: kind,
        entryId: entryId,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );
    } on AppFailure catch (failure) {
      // The web has nowhere private to keep a file, so there the photo really
      // does need a connection and the original failure is the honest answer.
      if (!shouldQueue(failure) || !files.canKeep) {
        rethrow;
      }
      final id = '$entryId-$fileName';
      final path = await files.keep(id: id, fileName: fileName, bytes: bytes);
      if (path == null) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: id,
          kind: PendingWriteKind.attachment,
          vehicleId: vehicleId,
          row: {
            'vehicle_id': vehicleId,
            'entry_kind': kind.key,
            'entry_id': entryId,
            'file_name': fileName,
            'content_type': contentType,
          },
          queuedAt: now(),
          attachment: PendingAttachment(
            path: path,
            fileName: fileName,
            contentType: contentType,
          ),
        ),
      );
      throw const AttachmentQueued();
    }
  }

  @override
  Future<List<Attachment>> forEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  }) => inner.forEntry(kind: kind, entryId: entryId);

  @override
  Future<Set<String>> entryIdsWithAttachments() =>
      inner.entryIdsWithAttachments();

  @override
  Future<Uri> viewUrl(Attachment attachment) => inner.viewUrl(attachment);

  @override
  Future<void> delete(Attachment attachment) => inner.delete(attachment);

  /// Forwarded, deliberately not queued. A deletion nobody can send is one the
  /// caller should hear about: the entry it belonged to is already gone, and
  /// silently accepting the request would say the receipt went with it.
  @override
  Future<void> deleteForEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  }) => inner.deleteForEntry(kind: kind, entryId: entryId);
}
