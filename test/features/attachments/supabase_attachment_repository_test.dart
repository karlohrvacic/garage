import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/data/supabase_attachment_repository.dart';

Map<String, dynamic> row({
  Object? contentType = 'image/jpeg',
  Object? sizeBytes = 2048,
}) {
  return {
    'id': 'a1',
    'vehicle_id': 'v1',
    'entry_kind': 'fuel',
    'entry_id': 'f1',
    'storage_path': 'v1/abc-receipt.jpg',
    'file_name': 'receipt.jpg',
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'created_by': 'u1',
    'created_at': '2026-07-24T10:30:00Z',
  };
}

Attachment attachment() {
  return Attachment(
    id: 'a1',
    vehicleId: 'v1',
    entryKind: AttachmentEntryKind.fuel,
    entryId: 'f1',
    storagePath: 'v1/abc-receipt.jpg',
    fileName: 'receipt.jpg',
    contentType: 'image/jpeg',
    sizeBytes: 2048,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 7, 24, 10, 30),
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(attachmentFromRow(row()), attachment());
    });

    test('reads the entry kind as the enum, not a bare string', () {
      expect(
        attachmentFromRow({...row(), 'entry_kind': 'service'}).entryKind,
        AttachmentEntryKind.service,
      );
    });

    test('keeps the timestamp in UTC', () {
      expect(attachmentFromRow(row()).createdAt.isUtc, isTrue);
    });

    test('a file with no known type or size still reads', () {
      final read = attachmentFromRow(row(contentType: null, sizeBytes: null));

      expect(read.contentType, isNull);
      expect(read.sizeBytes, isNull);
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(attachmentToRow(attachment()).keys, {
        'vehicle_id',
        'entry_kind',
        'entry_id',
        'storage_path',
        'file_name',
        'content_type',
        'size_bytes',
      });
    });

    test('writes the entry kind as its key', () {
      expect(attachmentToRow(attachment())['entry_kind'], 'fuel');
    });

    test('never sends id, created_by, or created_at', () {
      final written = attachmentToRow(attachment());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
      expect(written.containsKey('created_at'), isFalse);
    });
  });

  test('a row survives the round trip unchanged', () {
    final reread = attachmentFromRow({
      ...attachmentToRow(attachment()),
      'id': 'a1',
      'created_by': 'u1',
      'created_at': '2026-07-24T10:30:00Z',
    });

    expect(reread, attachment());
  });
}
