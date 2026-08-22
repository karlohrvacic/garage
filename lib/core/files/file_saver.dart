import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the user where to put a file and writes it there.
///
/// Returns true when a file was written, false when they backed out — the
/// distinction matters, because "saved" and "cancelled" must not produce the
/// same reassuring message.
typedef FileSaver =
    Future<bool> Function({
      required String fileName,
      required Uint8List bytes,
      required String mimeType,
    });

/// The system's save dialog, behind a provider so tests can assert what would
/// have been written without driving a platform dialog.
///
/// **Why `file_picker` and not `file_selector`,** which this project already
/// uses for *opening* files: `file_selector_android` implements exactly
/// `openFile`, `openFiles` and `getDirectoryPath` — it has no
/// `getSaveLocation` at all, so the platform interface's default throws
/// `UnimplementedError` on the one platform the app ships to. `file_picker`'s
/// `saveFile` works on Android (SAF `ACTION_CREATE_DOCUMENT`) and on the web
/// (a download), which is both of them.
///
/// Carrying two file-picking packages is a real cost and is not the end state:
/// the opening side should move here too so there is one picker with one set
/// of platform quirks. That is a separate change with its own blast radius —
/// three call sites, each with hard-won MIME-type workarounds for Android's
/// picker — and it is recorded in the decision log rather than done quietly
/// alongside a feature.
final fileSaverProvider = Provider<FileSaver>((ref) {
  return ({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return saved != null;
  };
});
