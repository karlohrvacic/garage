import 'export_file_name.dart';

/// When an automatic backup should run, and what it should be called.
///
/// Pure, because this is where the bugs would otherwise live: the platform
/// half of automatic backups cannot be unit-tested here, so everything that
/// *decides* anything is kept out of it.
///
/// Deliberately **not** a background task. Android's background execution is a
/// negotiation the app loses more often than it wins, and a backup that runs
/// unpredictably is worse than one that runs whenever the app is opened —
/// which is at least a moment the user can reason about.
abstract final class AutoBackupSchedule {
  /// How stale a backup has to be before another is written.
  ///
  /// A day. Short enough that losing a phone costs a day of logging, long
  /// enough that opening the app five times before lunch writes one file.
  static const Duration interval = Duration(hours: 24);

  /// Whether to write one now.
  ///
  /// [hasData] gates the very first backup: an empty garage produces a file
  /// that says nothing, and writing it daily into somebody's sync folder is
  /// noise dressed as diligence.
  static bool isDue({
    required DateTime? lastBackupAt,
    required DateTime now,
    required bool hasData,
  }) {
    if (!hasData) {
      return false;
    }
    if (lastBackupAt == null) {
      return true;
    }
    // A timestamp in the future means the clock moved, not that a backup
    // happened. Treating it as recent would stop backups forever on a device
    // whose time was wrong and then corrected — a silent, permanent failure.
    if (lastBackupAt.isAfter(now)) {
      return true;
    }
    return now.difference(lastBackupAt) >= interval;
  }

  /// The file to write, which is the same name all day.
  ///
  /// One file per day rather than one per run: the app can be opened many
  /// times in a day, and a sync folder filling with near-identical files is a
  /// backup feature making itself unwelcome. Overwriting within the day keeps
  /// the newest, and yesterday's is still there.
  static String fileNameFor(DateTime on) =>
      exportFileName(ExportKind.backup, on: on);
}
