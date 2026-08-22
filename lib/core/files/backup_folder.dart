import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

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
/// Storage Access Framework concept and has no equivalent on the web — a page
/// cannot hold write access to a directory across sessions. On the web these
/// report "no folder" and the feature simply does not offer itself.
///
/// Two packages rather than the single-package `saf`, which was tried first
/// and swapped out. `saf_stream` and `saf_util` carry roughly ten to sixteen
/// times the weekly downloads, which for the code that owns somebody's backups
/// is the number that matters — and, decisively, both declare **built-in
/// Kotlin support** while `saf` still ships a legacy Kotlin Gradle Plugin
/// configuration. A plugin applying its own KGP is a Gradle conflict waiting
/// for the next Android toolchain bump, and this project has its own Kotlin.
///
/// It is still behind a seam, and a failed write is still surfaced rather than
/// swallowed: if backups stop, the user has to find out from the app and not
/// from needing one.
bool get backupFoldersSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final _util = SafUtil();
final _stream = SafStream();

final backupFolderPickerProvider = Provider<BackupFolderPicker>((ref) {
  return () async {
    if (!backupFoldersSupported) {
      return null;
    }
    final directory = await _util.pickDirectory(
      writePermission: true,
      persistablePermission: true,
    );
    return directory?.uri;
  };
});

final backupFolderWriterProvider = Provider<BackupFolderWriter>((ref) {
  return ({
    required String folderUri,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // `overwrite`, because SAF's default on a name collision is to invent
    // `garage-backup-2026-08-22 (1).json`. One file per day means one file per
    // day, not a folder that grows every time the app is opened.
    await _stream.writeFileBytes(
      folderUri,
      fileName,
      'application/json',
      bytes,
      overwrite: true,
    );
  };
});

final backupFolderCheckProvider = Provider<BackupFolderCheck>((ref) {
  return (folderUri) async {
    if (!backupFoldersSupported) {
      return false;
    }
    // `checkWrite` is not the default and matters: a read-only grant would
    // pass the check and then fail at the write, which is the silent-stop
    // failure this whole feature is built to avoid.
    return _util.hasPersistedPermission(folderUri, checkWrite: true);
  };
});
