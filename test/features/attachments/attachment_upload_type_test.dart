import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/data/supabase_attachment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_supabase_http.dart';

final png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ...List.filled(64, 0),
]);

/// Storage accepts images and PDFs and nothing else (migration 0075), so the
/// type an attachment is sent as has to be what the file is — not what the
/// picker claimed, and not a guess storage makes when told nothing.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSupabaseServer server() => FakeSupabaseServer((request) {
    if (request.url.path.startsWith('/storage/v1/object/attachments/')) {
      return (200, {'Key': 'attachments/x'});
    }
    if (request.url.path == '/rest/v1/attachments') {
      return (
        201,
        {
          'id': 'a1',
          'vehicle_id': 'v1',
          'entry_kind': 'fuel',
          'entry_id': 'f1',
          'storage_path': 'v1/x-receipt.heic',
          'file_name': 'receipt.heic',
          'content_type': 'image/png',
          'size_bytes': png.length,
          'created_by': 'u1',
          'created_at': '2026-09-17T10:00:00Z',
        },
      );
    }
    return null;
  });

  test('a file is sent as what its bytes are', () async {
    final fake = server();
    await fake.signIn();

    await SupabaseAttachmentRepository(fake.client).upload(
      vehicleId: 'v1',
      kind: AttachmentEntryKind.fuel,
      entryId: 'f1',
      fileName: 'receipt.heic',
      bytes: png,
      contentType: 'image/heic',
    );

    final upload = fake.requests.singleWhere(
      (it) => it.url.path.startsWith('/storage/v1/object/attachments/'),
    );
    expect(
      latin1.decode(upload.bodyBytes).toLowerCase(),
      contains('content-type: image/png'),
    );
    final row = fake.requests.singleWhere(
      (it) => it.url.path == '/rest/v1/attachments',
    );
    expect(
      row.body,
      contains('"content_type":"image/png"'),
      reason: 'the row is what a viewer reads to decide how to open it',
    );
  });

  test('a file the picker named no type for still says one', () async {
    final fake = server();
    await fake.signIn();

    await SupabaseAttachmentRepository(fake.client).upload(
      vehicleId: 'v1',
      kind: AttachmentEntryKind.fuel,
      entryId: 'f1',
      // No extension either, so storage has nothing to guess from.
      fileName: 'receipt',
      bytes: png,
    );

    final upload = fake.requests.singleWhere(
      (it) => it.url.path.startsWith('/storage/v1/object/attachments/'),
    );
    expect(
      latin1.decode(upload.bodyBytes).toLowerCase(),
      contains('content-type: image/png'),
    );
  });
}
