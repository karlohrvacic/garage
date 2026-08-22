import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_log.dart';
import '../../../core/files/backup_folder.dart';
import '../../../domain/export/auto_backup_schedule.dart';
import '../../household/providers/household_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/backup_action.dart';

const _folderKey = 'backup.folderUri';
const _lastRunKey = 'backup.lastRunAt';

/// The folder automatic backups are written into, or null when the feature is
/// off — which is the default. Nothing is written anywhere until asked.
class AutoBackupFolder extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderKey);
  }

  /// Asks for a folder and remembers it. Returns whether one was chosen.
  Future<bool> choose() async {
    final picked = await ref.read(backupFolderPickerProvider)();
    if (picked == null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderKey, picked);
    // A new folder starts a new history: without this, switching folders looks
    // like it did nothing until tomorrow.
    await prefs.remove(_lastRunKey);
    state = AsyncValue.data(picked);
    return true;
  }

  Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderKey);
    await prefs.remove(_lastRunKey);
    state = const AsyncValue.data(null);
  }
}

final autoBackupFolderProvider =
    AsyncNotifierProvider<AutoBackupFolder, String?>(AutoBackupFolder.new);

/// When the last automatic backup was written, for the settings row.
final autoBackupLastRunProvider = FutureProvider<DateTime?>((ref) async {
  // Watched so writing a backup refreshes the row rather than leaving it
  // showing yesterday until the screen is rebuilt for some other reason.
  ref.watch(autoBackupFolderProvider);
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getInt(_lastRunKey);
  return stored == null ? null : DateTime.fromMillisecondsSinceEpoch(stored);
});

/// Writes a backup into the chosen folder if one is due.
///
/// Called when the app comes to the foreground rather than from a background
/// task: Android's background execution is a negotiation this app would lose,
/// and a backup that runs at an unpredictable time is harder to trust than one
/// that runs when you open the app.
///
/// **Failures are recorded, never swallowed.** A backup feature that quietly
/// stops is worse than none — the user finds out at the moment they needed it.
/// The failure goes to the same diagnostics log as everything else
/// (`adb logcat -s garage.failure`, and the Diagnostics screen).
Future<void> runAutoBackupIfDue(WidgetRef ref, {DateTime? now}) async {
  if (!backupFoldersSupported) {
    return;
  }
  final folder = await ref.read(autoBackupFolderProvider.future);
  if (folder == null) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getInt(_lastRunKey);
  final at = now ?? DateTime.now();
  final vehicles = await ref.read(allVehiclesProvider.future);

  if (!AutoBackupSchedule.isDue(
    lastBackupAt: stored == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(stored),
    now: at,
    hasData: vehicles.isNotEmpty,
  )) {
    return;
  }

  try {
    // Checked rather than assumed: a grant can be revoked from Android's own
    // settings, or the folder deleted. Writing blind would throw something
    // unhelpful and leave the user with no idea the folder was the problem.
    if (!await ref.read(backupFolderCheckProvider)(folder)) {
      throw StateError('the backup folder is no longer writable');
    }
    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null) {
      return;
    }
    final json = await buildBackup(ref: ref, householdName: household.name);
    await ref.read(backupFolderWriterProvider)(
      folderUri: folder,
      fileName: AutoBackupSchedule.fileNameFor(at),
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    await prefs.setInt(_lastRunKey, at.millisecondsSinceEpoch);
    ref.invalidate(autoBackupLastRunProvider);
  } catch (error) {
    // The timestamp is deliberately NOT written on failure, so the next
    // foreground tries again rather than waiting a day to fail identically.
    reportFailure(AppFailure.from(error));
  }
}
