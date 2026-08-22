import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/export/auto_backup_schedule.dart';

final _now = DateTime.utc(2026, 8, 22, 14, 30);

void main() {
  group('when an automatic backup is due', () {
    test('never backed up, and there is data: due', () {
      expect(
        AutoBackupSchedule.isDue(lastBackupAt: null, now: _now, hasData: true),
        isTrue,
      );
    });

    test('never backed up, and there is nothing yet: not due', () {
      // A backup of an empty garage is a file that says nothing, written into
      // somebody's sync folder every day.
      expect(
        AutoBackupSchedule.isDue(lastBackupAt: null, now: _now, hasData: false),
        isFalse,
      );
    });

    test('backed up an hour ago: not due', () {
      expect(
        AutoBackupSchedule.isDue(
          lastBackupAt: _now.subtract(const Duration(hours: 1)),
          now: _now,
          hasData: true,
        ),
        isFalse,
      );
    });

    test('backed up just over a day ago: due', () {
      expect(
        AutoBackupSchedule.isDue(
          lastBackupAt: _now.subtract(const Duration(hours: 24, minutes: 1)),
          now: _now,
          hasData: true,
        ),
        isTrue,
      );
    });

    test('a clock that went backwards does not block backups forever', () {
      // A device whose time was wrong and got corrected would otherwise have a
      // "last backup" in the future and never back up again.
      expect(
        AutoBackupSchedule.isDue(
          lastBackupAt: _now.add(const Duration(days: 400)),
          now: _now,
          hasData: true,
        ),
        isTrue,
      );
    });

    test('the interval is a day, and it is stated once', () {
      expect(AutoBackupSchedule.interval, const Duration(hours: 24));
    });
  });

  group('what an automatic backup is called', () {
    test('is dated, so a folder keeps a history rather than one file', () {
      expect(
        AutoBackupSchedule.fileNameFor(_now),
        'garage-backup-2026-08-22.json',
      );
    });

    test('twice in one day overwrites rather than piling up', () {
      // Same name inside a day: an auto-backup that ran on every foreground
      // would otherwise fill a sync folder with near-identical files.
      expect(
        AutoBackupSchedule.fileNameFor(_now),
        AutoBackupSchedule.fileNameFor(_now.add(const Duration(hours: 5))),
      );
    });

    test('a different day is a different file', () {
      expect(
        AutoBackupSchedule.fileNameFor(_now),
        isNot(
          AutoBackupSchedule.fileNameFor(_now.add(const Duration(days: 1))),
        ),
      );
    });
  });
}
