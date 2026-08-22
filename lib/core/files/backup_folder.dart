import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_folder_web.dart'
    if (dart.library.io) 'backup_folder_io.dart'
    as platform;

/// Asks for a folder to keep automatic backups in. Null if the user backed out.
typedef BackupFolderPicker = Future<String?> Function();

/// Writes one file into a previously granted folder. Throws on failure —
/// callers must not treat a failed backup as a quiet non-event.
typedef BackupFolderWriter =
    Future<void> Function({
      required String folderUri,
      required String fileName,
      required Uint8List bytes,
    });

/// Whether the grant for a folder is still held.
typedef BackupFolderCheck = Future<bool> Function(String folderUri);

/// Where automatic backups go, behind providers so the whole feature is
/// testable without a device.
///
/// **Android only.** Choosing a folder the app can still write to tomorrow is
/// `ACTION_OPEN_DOCUMENT_TREE` plus `takePersistableUriPermission`, which is a
/// Storage Access Framework concept with no equivalent on the web — a page
/// cannot hold write access to a directory across sessions.
///
/// **The web build is why this is split across three files.** `saf_stream`
/// depends on `jni`, which imports `dart:ffi`, which dart2js cannot compile.
/// A plain `kIsWeb` check at runtime is not enough: the import alone breaks
/// the build. Neither `flutter analyze` nor `flutter test` can see that —
/// `flutter build web` is the only thing that does, and it caught this in CI
/// after both passed locally.
///
/// Two packages rather than the single-package `saf`, which was tried first:
/// `saf_stream` and `saf_util` carry roughly ten to sixteen times the weekly
/// downloads, which for the code that owns somebody's backups is the number
/// that matters — and both declare **built-in Kotlin support** while `saf`
/// still ships a legacy Kotlin Gradle Plugin configuration, a Gradle conflict
/// waiting for the next Android toolchain bump.
///
/// A failed write is surfaced rather than swallowed: if backups stop, the user
/// has to find out from the app and not from needing one.
bool get backupFoldersSupported =>
    !kIsWeb && platform.platformSupportsBackupFolders;

final backupFolderPickerProvider = Provider<BackupFolderPicker>((ref) {
  return () async {
    if (!backupFoldersSupported) {
      return null;
    }
    return platform.pickFolder();
  };
});

final backupFolderWriterProvider = Provider<BackupFolderWriter>((ref) {
  return ({
    required String folderUri,
    required String fileName,
    required Uint8List bytes,
  }) => platform.writeFile(
    folderUri: folderUri,
    fileName: fileName,
    bytes: bytes,
  );
});

final backupFolderCheckProvider = Provider<BackupFolderCheck>((ref) {
  return (folderUri) async {
    if (!backupFoldersSupported) {
      return false;
    }
    return platform.holdsWritePermission(folderUri);
  };
});
