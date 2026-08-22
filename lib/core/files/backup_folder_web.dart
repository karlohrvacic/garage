import 'package:flutter/foundation.dart';

/// The web's answer to all of this: no.
///
/// A page cannot hold write access to a directory across sessions, so there is
/// nothing to pick and nothing to write. Kept as a separate file rather than a
/// runtime `kIsWeb` branch because the point is to stop `saf_stream` — and
/// through it `jni` and `dart:ffi` — from ever reaching dart2js at all.
bool get platformSupportsBackupFolders => false;

Future<String?> pickFolder() async => null;

Future<void> writeFile({
  required String folderUri,
  required String fileName,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('backup folders are not available on the web');
}

Future<bool> holdsWritePermission(String folderUri) async => false;
