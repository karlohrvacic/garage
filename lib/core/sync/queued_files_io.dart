import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

bool get canQueueFiles => true;

Future<Directory> _folder() async {
  // Application *support*, not documents: these are the app's own working
  // files, not something a person should meet in a file browser.
  final base = await getApplicationSupportDirectory();
  final folder = Directory('${base.path}/pending');
  if (!folder.existsSync()) {
    await folder.create(recursive: true);
  }
  return folder;
}

Future<String?> keepFile({
  required String id,
  required String fileName,
  required Uint8List bytes,
}) async {
  try {
    final folder = await _folder();
    // Named by the entry's own id, so a second attempt at the same photo
    // replaces the first rather than leaving one behind that nothing points at
    // — the same rule the vehicle-photo path follows.
    final file = File('${folder.path}/$id');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    // A full disk, or a sandbox that refused. The entry still queues; the
    // photo is what is lost, and the caller says so.
    return null;
  }
}

Future<Uint8List?> readKeptFile(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<void> discardKeptFile(String path) async {
  try {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  } catch (_) {
    // Nothing to do about it, and nothing worth failing an upload for.
  }
}
