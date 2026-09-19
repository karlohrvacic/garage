import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/features/documents/data/supabase_document_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> row() {
  return {
    'id': 'd1',
    'vehicle_id': 'v1',
    'doc_type': 'registration',
    'label': null,
    'number': 'ZG 1234 AB',
    'issuer': 'MUP',
    'issued_on': '2026-03-01',
    'expires_on': '2027-03-01',
    'notes': null,
    'created_by': 'u1',
    'created_at': '2026-03-01T10:00:00Z',
  };
}

void main() {
  test('a row maps onto the entity, dates as UTC days', () {
    final document = documentFromRow(row());

    expect(document.type, DocumentType.registration);
    expect(document.number, 'ZG 1234 AB');
    expect(document.issuedOn, DateTime.utc(2026, 3, 1));
    expect(document.expiresOn, DateTime.utc(2027, 3, 1));
    expect(document.createdBy, 'u1');
  });

  test('a row survives the round trip unchanged', () {
    final document = documentFromRow(row());

    expect(
      documentFromRow({
        ...documentToRow(document),
        'id': 'd1',
        'created_by': 'u1',
        'created_at': '2026-03-01T10:00:00Z',
      }),
      document,
    );
  });

  // A driver reads the assigned car's papers and holds no write on them
  // (migration 0080). An edit is an upsert, which Postgres checks against
  // the insert policy and refuses out loud; a delete is answered with zero
  // rows rather than an error, so the repository reads the id back and
  // treats none as the refusal it is.
  group('a delete the policy filtered', () {
    SupabaseDocumentRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseDocumentRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('reads back the row it took', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'd1'},
          ],
        ),
      );

      await repositoryOver(server).delete('d1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/rest/v1/vehicle_documents');
      expect(sent.url.queryParameters['id'], 'eq.d1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).delete('d1'),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });

    test('an edit is an upsert, which the insert policy answers', () async {
      final server = FakeSupabaseServer((request) => (201, const []));
      await server.signIn(userId: 'u2');

      await repositoryOver(server).save(documentFromRow(row()));

      final sent = server.requests.last;
      expect(sent.method, 'POST');
      expect(sent.headers['prefer'], contains('resolution=merge-duplicates'));
      expect(jsonDecode(sent.body)['created_by'], 'u2');
    });
  });
}
