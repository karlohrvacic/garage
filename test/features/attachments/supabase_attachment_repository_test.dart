import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/data/supabase_attachment_repository.dart';

import '../../support/fake_supabase_http.dart';

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

  // A driver sees every receipt on the assigned car and may take down only
  // their own (migration 0080). Postgres answers the delete the policy
  // filters out with zero rows rather than an error, so the repository reads
  // the id back and treats none as the refusal it is — before touching the
  // file, which the row still points at.
  group('a delete the policy filtered', () {
    test('takes the row, then the file', () async {
      final server = FakeSupabaseServer((request) {
        if (request.url.path == '/rest/v1/attachments') {
          return (
            200,
            const [
              {'id': 'a1'},
            ],
          );
        }
        if (request.url.path == '/storage/v1/object/attachments') {
          return (200, const []);
        }
        return null;
      });

      await SupabaseAttachmentRepository(server.client).delete(attachment());

      expect(server.requests, hasLength(2));
      final row = server.requests.first;
      expect(row.method, 'DELETE');
      expect(row.url.queryParameters['id'], 'eq.a1');
      expect(row.url.queryParameters['select'], 'id');
      expect(server.requests.last.url.path, '/storage/v1/object/attachments');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        SupabaseAttachmentRepository(server.client).delete(attachment()),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
      expect(
        server.requests,
        hasLength(1),
        reason: 'the file is left where the row still points',
      );
    });
  });
}
