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

/// A Garage backup file, which is JSON rather than CSV.
final restoreFilePickerProvider = Provider<FilePicker>((ref) {
  return () => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Garage backup',
        extensions: ['json', 'txt'],
        // Android's picker matches on MIME type, and a file provider that
        // reports JSON as octet-stream would otherwise grey out the very file
        // the user is looking at.
        mimeTypes: [
          'application/json',
          'text/json',
          'text/plain',
          'application/octet-stream',
        ],
      ),
    ],
  );
});

/// The backup file for an import.
///
/// Both `mimeTypes` and `extensions` are given: Android's picker matches on
/// MIME type, and a CSV that a file provider reports as `text/plain` or
/// `application/octet-stream` would otherwise be greyed out — the file is
/// right there and cannot be chosen.
final backupFilePickerProvider = Provider<FilePicker>((ref) {
  return () => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'CSV backup',
        extensions: ['csv', 'txt'],
        mimeTypes: [
          'text/csv',
          'text/comma-separated-values',
          'text/plain',
          'application/csv',
          'application/octet-stream',
        ],
      ),
    ],
  );
});
