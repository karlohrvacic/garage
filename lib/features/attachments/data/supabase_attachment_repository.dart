import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/attachment.dart';
import 'attachment_repository.dart';

/// How long a view URL stays good. Long enough to open the file, short enough
/// that a leaked link is worthless by the time it travels.
const _signedUrlSeconds = 600;

const _bucket = 'attachments';

class SupabaseAttachmentRepository implements AttachmentRepository {
  SupabaseAttachmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Attachment>> forEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  }) async {
    try {
      final rows = await _client
          .from('attachments')
          .select()
          .eq('entry_kind', kind.key)
          .eq('entry_id', entryId)
          .order('created_at', ascending: true);
      return rows.map(attachmentFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Attachment> upload({
    required String vehicleId,
    required AttachmentEntryKind kind,
    required String entryId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final path = Attachment.storagePathFor(
      vehicleId: vehicleId,
      uniqueId: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      fileName: fileName,
    );
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );
      final row = await _client
          .from('attachments')
          .insert({
            'vehicle_id': vehicleId,
            'entry_kind': kind.key,
            'entry_id': entryId,
            'storage_path': path,
            'file_name': fileName,
            'content_type': contentType,
            'size_bytes': bytes.length,
            'created_by': _client.auth.currentUser!.id,
          })
          .select()
          .single();
      return attachmentFromRow(row);
    } catch (error) {
      // The row is what makes a file visible; an upload that failed to record
      // itself would otherwise leave an orphan nobody can see or remove.
      await _client.storage
          .from(_bucket)
          .remove([path])
          .catchError((_) => <FileObject>[]);
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Uri> viewUrl(Attachment attachment) async {
    try {
      final url = await _client.storage
          .from(_bucket)
          .createSignedUrl(attachment.storagePath, _signedUrlSeconds);
      return Uri.parse(url);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(Attachment attachment) async {
    try {
      await _client.from('attachments').delete().eq('id', attachment.id);
      await _client.storage.from(_bucket).remove([attachment.storagePath]);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The writable half of an `attachments` row; the id, uploader, and timestamp
/// are the server's.
Map<String, dynamic> attachmentToRow(Attachment attachment) {
  return {
    'vehicle_id': attachment.vehicleId,
    'entry_kind': attachment.entryKind.key,
    'entry_id': attachment.entryId,
    'storage_path': attachment.storagePath,
    'file_name': attachment.fileName,
    'content_type': attachment.contentType,
    'size_bytes': attachment.sizeBytes,
  };
}

Attachment attachmentFromRow(Map<String, dynamic> row) {
  return Attachment(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    entryKind: AttachmentEntryKind.fromKey(row['entry_kind'] as String),
    entryId: row['entry_id'] as String,
    storagePath: row['storage_path'] as String,
    fileName: row['file_name'] as String,
    contentType: row['content_type'] as String?,
    sizeBytes: (row['size_bytes'] as num?)?.toInt(),
    createdBy: row['created_by'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
