import 'dart:typed_data';

/// The web has no private directory to hold a photo between one signal and the
/// next, so nothing is kept and the caller says so.
bool get canQueueFiles => false;

Future<String?> keepFile({
  required String id,
  required String fileName,
  required Uint8List bytes,
}) async => null;

Future<Uint8List?> readKeptFile(String path) async => null;

Future<void> discardKeptFile(String path) async {}
