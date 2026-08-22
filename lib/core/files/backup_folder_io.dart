import 'package:flutter/foundation.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

/// The real Storage Access Framework calls, on any platform that has
/// `dart:io`. Selected by the conditional import in `backup_folder.dart`.
///
/// This file exists **only** so that `saf_stream` never reaches the web
/// compiler. It depends on `jni`, which imports `dart:ffi`, which dart2js
/// cannot compile — and neither `flutter analyze` nor `flutter test` can see
/// that. `flutter build web` is the only thing that catches it, which is
/// exactly how it reached CI once already.
final _util = SafUtil();
final _stream = SafStream();

/// Android only in practice: a folder grant that outlives the picker is a SAF
/// concept, and the app ships nowhere else with `dart:io`.
bool get platformSupportsBackupFolders =>
    defaultTargetPlatform == TargetPlatform.android;

Future<String?> pickFolder() async {
  final directory = await _util.pickDirectory(
    writePermission: true,
    persistablePermission: true,
  );
  return directory?.uri;
}

Future<void> writeFile({
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
}

/// `checkWrite` is not the default and matters: a read-only grant would pass
/// the check and then fail at the write, which is the silent-stop failure this
/// whole feature is built to avoid.
Future<bool> holdsWritePermission(String folderUri) =>
    _util.hasPersistedPermission(folderUri, checkWrite: true);
