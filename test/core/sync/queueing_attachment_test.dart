import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/queueing_attachment_repository.dart';
import 'package:garage/core/sync/queued_files.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/data/attachment_repository.dart';

class FlakyAttachments implements AttachmentRepository {
  FlakyAttachments({this.failWith});

  AppFailureKind? failWith;
  final List<String> uploaded = [];
  final List<String> sweptEntries = [];

  @override
  Future<Attachment> upload({
    required String vehicleId,
    required AttachmentEntryKind kind,
    required String entryId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (failWith != null) {
      throw AppFailure(kind: failWith!);
    }
    uploaded.add(fileName);
    return Attachment(
      id: 'a1',
      vehicleId: vehicleId,
      entryKind: kind,
      entryId: entryId,
      storagePath: 'p',
      fileName: fileName,
      createdBy: 'u1',
      createdAt: DateTime.utc(2026, 9, 5),
    );
  }

  @override
  Future<void> deleteForEntry({
    required AttachmentEntryKind kind,
    required String entryId,
  }) async {
    sweptEntries.add(entryId);
    if (failWith != null) {
      throw AppFailure(kind: failWith!);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Holds a file without a disk, so the test is about the queueing rather than
/// about whether path_provider has a platform channel.
class FakeFiles implements QueuedFileStore {
  FakeFiles({this.canKeep = true});

  @override
  final bool canKeep;
  final Map<String, Uint8List> kept = {};

  @override
  Future<String?> keep({
    required String id,
    required String fileName,
    required Uint8List bytes,
  }) async {
    kept['/tmp/$id'] = bytes;
    return '/tmp/$id';
  }

  @override
  Future<Uint8List?> read(String path) async => kept[path];

  @override
  Future<void> discard(String path) async => kept.remove(path);
}

void main() {
  late FlakyAttachments inner;
  late InMemoryPendingWriteStore queue;
  late QueueingAttachmentRepository repository;
  late FakeFiles files;

  setUp(() {
    inner = FlakyAttachments();
    queue = InMemoryPendingWriteStore();
    files = FakeFiles();
    repository = QueueingAttachmentRepository(
      inner: inner,
      queue: queue,
      now: () => DateTime.utc(2026, 9, 5, 7),
      files: files,
    );
  });

  Future<Attachment> attach() => repository.upload(
    vehicleId: 'v1',
    kind: AttachmentEntryKind.fuel,
    entryId: 'e1',
    fileName: 'receipt.jpg',
    bytes: Uint8List.fromList([1, 2, 3]),
    contentType: 'image/jpeg',
  );

  test('an upload that works queues nothing', () async {
    await attach();

    expect(inner.uploaded, ['receipt.jpg']);
    expect(await queue.all(), isEmpty);
  });

  test('a rejection is still a rejection', () async {
    // A file too large, or a bucket that refused. Keeping it and retrying for
    // ever would hide a message the person can act on.
    inner.failWith = AppFailureKind.invalid;

    await expectLater(attach(), throwsA(isA<AppFailure>()));
    expect(await queue.all(), isEmpty);
  });

  test(
    'losing the connection keeps the photo, and says so distinctly',
    () async {
      // Not an AppFailure: nothing went wrong. The file is on the phone.
      inner.failWith = AppFailureKind.network;

      await expectLater(attach(), throwsA(isA<AttachmentQueued>()));

      if (!canQueueFiles) {
        // The web has nowhere to put it; this test only asserts the platform
        // split holds, and the branch above never runs there.
        return;
      }
      final queued = await queue.all();
      expect(queued.single.kind, PendingWriteKind.attachment);
      expect(queued.single.attachment?.fileName, 'receipt.jpg');
      expect(queued.single.row['entry_id'], 'e1');
      expect(queued.single.row['entry_kind'], AttachmentEntryKind.fuel.key);
    },
  );

  test('the same photo queued twice is queued once', () async {
    inner.failWith = AppFailureKind.network;

    await expectLater(attach(), throwsA(isA<AttachmentQueued>()));
    await expectLater(attach(), throwsA(isA<AttachmentQueued>()));

    expect(await queue.all(), hasLength(1));
  });

  test(
    'where a file cannot be kept, the failure is the honest answer',
    () async {
      // The web. There is nowhere private to hold a photo between one signal and
      // the next, so saying "kept, it will upload" would be untrue.
      inner.failWith = AppFailureKind.network;
      repository = QueueingAttachmentRepository(
        inner: inner,
        queue: queue,
        now: () => DateTime.utc(2026, 9, 5, 7),
        files: FakeFiles(canKeep: false),
      );

      await expectLater(attach(), throwsA(isA<AppFailure>()));
      expect(await queue.all(), isEmpty);
    },
  );

  group('an entry deleted while its photo waits', () {
    // A fill-up saved with no signal can now be deleted from the phone before
    // it is ever sent. Its receipt, queued beside it, would otherwise go up on
    // its own later and hang off an entry that does not exist.
    setUp(() async {
      inner.failWith = AppFailureKind.network;
      await expectLater(attach(), throwsA(isA<AttachmentQueued>()));
    });

    test('takes the photo off the phone too', () async {
      await expectLater(
        repository.deleteForEntry(
          kind: AttachmentEntryKind.fuel,
          entryId: 'e1',
        ),
        throwsA(isA<AppFailure>()),
        reason: 'the server half still has to be told, and could not be',
      );

      expect(await queue.all(), isEmpty);
      expect(files.kept, isEmpty);
    });

    test('and still sweeps the server for photos that did go up', () async {
      inner.failWith = null;

      await repository.deleteForEntry(
        kind: AttachmentEntryKind.fuel,
        entryId: 'e1',
      );

      expect(inner.sweptEntries, ['e1']);
      expect(await queue.all(), isEmpty);
    });

    test('leaves another entry\'s photo where it is', () async {
      await repository
          .deleteForEntry(kind: AttachmentEntryKind.fuel, entryId: 'e2')
          .catchError((_) {});
      await repository
          .deleteForEntry(kind: AttachmentEntryKind.cost, entryId: 'e1')
          .catchError((_) {});

      expect(await queue.all(), hasLength(1));
      expect(files.kept, hasLength(1));
    });
  });
}
