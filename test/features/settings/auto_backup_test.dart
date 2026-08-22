import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/core/files/backup_folder.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/settings/providers/auto_backup_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_restore_test.dart'
    show
        FakeCosts,
        FakeFuel,
        FakeIncome,
        FakeMaintenance,
        FakeOdometer,
        FakeTrips,
        FakeTyres,
        FakeVehicles,
        fill,
        golf,
        withRef;

/// Records what would have been written into the chosen folder.
class RecordingFolder {
  final List<({String folderUri, String fileName, int bytes})> written = [];
  bool writable = true;
  bool throwOnWrite = false;

  Future<void> write({
    required String folderUri,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (throwOnWrite) {
      throw Exception('the card was pulled out');
    }
    written.add((
      folderUri: folderUri,
      fileName: fileName,
      bytes: bytes.length,
    ));
  }

  Future<bool> check(String uri) async => writable;
}

List<Override> overridesFor(RecordingFolder folder, {bool hasVehicle = true}) {
  final vehicles = FakeVehicles(hasVehicle ? [golf()] : []);
  return [
    vehicleRepositoryProvider.overrideWithValue(vehicles),
    fuelRepositoryProvider.overrideWithValue(FakeFuel([fill()])),
    costRepositoryProvider.overrideWithValue(FakeCosts()),
    odometerRepositoryProvider.overrideWithValue(FakeOdometer()),
    tripRepositoryProvider.overrideWithValue(FakeTrips()),
    incomeRepositoryProvider.overrideWithValue(FakeIncome()),
    maintenanceRepositoryProvider.overrideWithValue(FakeMaintenance()),
    tyreRepositoryProvider.overrideWithValue(FakeTyres()),
    allVehiclesProvider.overrideWith((ref) async => vehicles.vehicles),
    currentHouseholdProvider.overrideWith(
      (ref) async => const Household(id: 'h1', name: 'Hrvačić'),
    ),
    backupFolderWriterProvider.overrideWithValue(folder.write),
    backupFolderCheckProvider.overrideWithValue(folder.check),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    forgetRecordedFailuresInMemory();
  });

  // The test host reports Android, so the whole path below really runs.
  test('the feature is available where a folder grant can persist', () {
    expect(backupFoldersSupported, isTrue);
  });

  group('choosing a folder', () {
    testWidgets('remembers what was picked', (tester) async {
      final folder = RecordingFolder();
      await withRef(
        tester,
        [
          ...overridesFor(folder),
          backupFolderPickerProvider.overrideWithValue(
            () async => 'content://tree/backups',
          ),
        ],
        (ref) async {
          final chose = await ref
              .read(autoBackupFolderProvider.notifier)
              .choose();

          expect(chose, isTrue);
          expect(
            await ref.read(autoBackupFolderProvider.future),
            'content://tree/backups',
          );
        },
      );
    });

    testWidgets('backing out of the picker changes nothing', (tester) async {
      final folder = RecordingFolder();
      await withRef(
        tester,
        [
          ...overridesFor(folder),
          backupFolderPickerProvider.overrideWithValue(() async => null),
        ],
        (ref) async {
          expect(
            await ref.read(autoBackupFolderProvider.notifier).choose(),
            isFalse,
          );
          expect(await ref.read(autoBackupFolderProvider.future), isNull);
        },
      );
    });

    testWidgets('stopping forgets the folder', (tester) async {
      final folder = RecordingFolder();
      await withRef(
        tester,
        [
          ...overridesFor(folder),
          backupFolderPickerProvider.overrideWithValue(
            () async => 'content://tree/backups',
          ),
        ],
        (ref) async {
          final notifier = ref.read(autoBackupFolderProvider.notifier);
          await notifier.choose();
          await notifier.forget();

          expect(await ref.read(autoBackupFolderProvider.future), isNull);
        },
      );
    });
  });

  Future<void> withFolder(
    WidgetTester tester,
    RecordingFolder folder,
    Future<void> Function(WidgetRef ref) run, {
    bool hasVehicle = true,
  }) {
    return withRef(
      tester,
      [
        ...overridesFor(folder, hasVehicle: hasVehicle),
        backupFolderPickerProvider.overrideWithValue(
          () async => 'content://tree/backups',
        ),
      ],
      (ref) async {
        await ref.read(autoBackupFolderProvider.notifier).choose();
        await run(ref);
      },
    );
  }

  group('writing one', () {
    testWidgets('writes a dated backup into the chosen folder', (tester) async {
      final folder = RecordingFolder();
      await withFolder(tester, folder, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22));
      });

      expect(folder.written, hasLength(1));
      expect(folder.written.single.folderUri, 'content://tree/backups');
      expect(folder.written.single.fileName, 'garage-backup-2026-08-22.json');
      expect(folder.written.single.bytes, greaterThan(0));
    });

    testWidgets('does not write again the same day', (tester) async {
      final folder = RecordingFolder();
      await withFolder(tester, folder, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22, 9));
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22, 17));
      });

      expect(
        folder.written,
        hasLength(1),
        reason: 'opening the app twice must not fill a sync folder',
      );
    });

    testWidgets('writes again once a day has passed', (tester) async {
      final folder = RecordingFolder();
      await withFolder(tester, folder, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22, 9));
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 23, 10));
      });

      expect(folder.written.map((w) => w.fileName), [
        'garage-backup-2026-08-22.json',
        'garage-backup-2026-08-23.json',
      ]);
    });

    testWidgets('writes nothing with no folder chosen', (tester) async {
      final folder = RecordingFolder();
      await withRef(tester, overridesFor(folder), (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22));
      });

      expect(folder.written, isEmpty);
    });

    testWidgets('writes nothing for a garage with no cars in it', (
      tester,
    ) async {
      // A backup of an empty garage is a file that says nothing, landing in
      // somebody's sync folder every day.
      final folder = RecordingFolder();
      await withFolder(tester, folder, hasVehicle: false, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22));
      });

      expect(folder.written, isEmpty);
    });
  });

  // The failure that matters most for a backup feature is the silent one: it
  // stops working and nobody finds out until they need it.
  group('when a backup cannot be written', () {
    testWidgets('a revoked folder grant is recorded, not swallowed', (
      tester,
    ) async {
      final folder = RecordingFolder()..writable = false;
      await withFolder(tester, folder, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22));
      });

      expect(folder.written, isEmpty);
      expect(
        recordedFailures.join('\n'),
        contains('no longer writable'),
        reason: 'the user has to be able to find out backups stopped',
      );
    });

    testWidgets('a failed write is recorded too', (tester) async {
      final folder = RecordingFolder()..throwOnWrite = true;
      await withFolder(tester, folder, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22));
      });

      expect(recordedFailures, isNotEmpty);
    });

    testWidgets('a failure does not block tomorrow, or even the next try', (
      tester,
    ) async {
      // The timestamp is only written on success, so a transient failure is
      // retried on the next foreground rather than waiting a day to fail again.
      final folder = RecordingFolder()..throwOnWrite = true;
      await withFolder(tester, folder, (ref) async {
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22, 9));
        folder.throwOnWrite = false;
        await runAutoBackupIfDue(ref, now: DateTime(2026, 8, 22, 10));
      });

      expect(folder.written, hasLength(1));
    });
  });
}
