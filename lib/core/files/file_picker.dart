import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the user for one file, or null if they backed out.
typedef FilePicker = Future<XFile?> Function();

/// The system file picker, behind a provider so tests can hand a file straight
/// to the code under test instead of driving a platform dialog.
final filePickerProvider = Provider<FilePicker>((ref) {
  return () => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Receipts and documents',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
        mimeTypes: ['image/*', 'application/pdf'],
      ),
    ],
  );
});
