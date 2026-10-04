import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/backup_folder.dart';

/// Whether the folder automatic backups go into can still be written to.
///
/// A held grant is not enough. Android keeps the grant after the folder is
/// deleted or moved, so the check passed and the write failed at
/// `createFile` with "File creation failed at garage-backup-….json" — on a
/// phone in production, every day, with nothing in the app saying why.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('saf_util');
  const folder = 'content://com.android.externalstorage.documents/tree/x';

  late bool granted;
  late bool exists;
  late List<String> asked;

  setUp(() {
    granted = true;
    exists = true;
    asked = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          asked.add(call.method);
          final arguments = call.arguments as Map;
          expect(arguments['uri'], folder);
          return switch (call.method) {
            'hasPersistedPermission' =>
              arguments['checkWrite'] == true && granted,
            'exists' => arguments['isDir'] == true && exists,
            _ => throw MissingPluginException(call.method),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<bool> check() =>
      ProviderContainer().read(backupFolderCheckProvider)(folder);

  test('a held grant on a folder that is there is writable', () async {
    expect(await check(), isTrue);
  });

  test('a held grant on a folder that is gone is not', () async {
    exists = false;

    expect(await check(), isFalse);
  });

  test('a folder with no grant is not, whether or not it is there', () async {
    granted = false;

    expect(await check(), isFalse);
    expect(asked, ['hasPersistedPermission']);
  });
}
