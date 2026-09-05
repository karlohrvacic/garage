import 'dart:typed_data';

import 'queued_files_stub.dart'
    if (dart.library.io) 'queued_files_io.dart'
    as platform;

/// Somewhere private to keep a photo until its upload can happen.
///
/// The conditional import is the pattern `backup_folder.dart` already uses,
/// and for the same reason: `dart:io` must never reach the web compiler, and
/// neither `flutter analyze` nor `flutter test` notices when it does —
/// `flutter build web` is the only thing that catches it.
///
/// On the web there is nowhere to put one, so nothing is queued and the person
/// is told the photo needs a connection. The entry itself still queues.
bool get canQueueFiles => platform.canQueueFiles;

/// Writes [bytes] somewhere the app owns and returns the path.
Future<String?> keepFile({
  required String id,
  required String fileName,
  required Uint8List bytes,
}) => platform.keepFile(id: id, fileName: fileName, bytes: bytes);

/// Reads one back, or null when it is gone.
Future<Uint8List?> readKeptFile(String path) => platform.readKeptFile(path);

/// Removes one once it has been uploaded, so the queue does not become a
/// second photo library.
Future<void> discardKeptFile(String path) => platform.discardKeptFile(path);

/// The seam. A platform capability reached through an interface rather than a
/// global, so a test can fake it — the same rule the file picker and the URL
/// opener already follow.
abstract interface class QueuedFileStore {
  /// False where there is nowhere private to keep a file, which is the web.
  bool get canKeep;

  Future<String?> keep({
    required String id,
    required String fileName,
    required Uint8List bytes,
  });

  Future<Uint8List?> read(String path);

  Future<void> discard(String path);
}

class PlatformQueuedFileStore implements QueuedFileStore {
  const PlatformQueuedFileStore();

  @override
  bool get canKeep => canQueueFiles;

  @override
  Future<String?> keep({
    required String id,
    required String fileName,
    required Uint8List bytes,
  }) => keepFile(id: id, fileName: fileName, bytes: bytes);

  @override
  Future<Uint8List?> read(String path) => readKeptFile(path);

  @override
  Future<void> discard(String path) => discardKeptFile(path);
}
