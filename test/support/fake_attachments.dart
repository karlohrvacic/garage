import 'dart:typed_data';

import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/data/attachment_repository.dart';

/// A repository that keeps attachments in a list, for tests that must not
/// reach a real Supabase client.
class FakeAttachmentRepository implements AttachmentRepository {
  FakeAttachmentRepository([this.stored = const []]);

  List<Attachment> stored;
  final List<String> calls = [];

  @override
  Future<Set<String>> entryIdsWithAttachments() async => {
    for (final a in stored) a.entryId,
  };

  /// Matches on the kind alone, for a sheet whose entry id is minted inside
  /// it and never handed out. Without this a test cannot seed an attachment
  /// against the row the sheet is about to abandon.
  bool matchAnyEntry = false;

  @override
  Future<List<Attachment>> forEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  }) async {
    calls.add('forEntry:${kind.key}:$entryId');
    return [
      for (final item in stored)
        if (item.entryKind == kind &&
            (matchAnyEntry || item.entryId == entryId))
          item,
    ];
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
    calls.add('upload:$fileName:${bytes.length}');
    final uploaded = attachment(
      id: 'new',
      kind: kind,
      entryId: entryId,
      fileName: fileName,
    );
    stored = [...stored, uploaded];
    return uploaded;
  }

  @override
  Future<Uri> viewUrl(Attachment attachment) async {
    calls.add('viewUrl:${attachment.id}');
    return Uri.parse('https://example.test/${attachment.storagePath}');
  }

  /// Fails the sweep, for the test about an entry deletion that must land
  /// anyway.
  bool failSweep = false;

  @override
  Future<void> deleteForEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  }) async {
    calls.add('deleteForEntry:${kind.key}:$entryId');
    if (failSweep) {
      throw const AppFailure(kind: AppFailureKind.network);
    }
    stored = [
      for (final item in stored)
        if (item.entryKind != kind || item.entryId != entryId) item,
    ];
  }

  @override
  Future<void> delete(Attachment attachment) async {
    calls.add('delete:${attachment.id}');
    stored = stored.where((item) => item.id != attachment.id).toList();
  }
}

Attachment attachment({
  String id = 'a1',
  AttachmentEntryKind kind = AttachmentEntryKind.fuel,
  String entryId = 'f1',
  String fileName = 'receipt.jpg',
}) {
  return Attachment(
    id: id,
    vehicleId: 'v1',
    entryKind: kind,
    entryId: entryId,
    storagePath: 'v1/$id-$fileName',
    fileName: fileName,
    contentType: 'image/jpeg',
    sizeBytes: 1024,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 7, 24),
  );
}
