import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/export/export_file_name.dart';

final _on = DateTime(2026, 8, 22);

void main() {
  // Every export arrived called something like `3f9a1c-8e21.json`, because
  // `XFile.fromData` drops its `name` on every platform but web and share_plus
  // then falls back to a UUID. The name is fixed at the call site now, but it
  // is only worth fixing into something a person can find again later.
  group('what an exported file is called', () {
    test('a backup names itself and the day it was taken', () {
      expect(
        exportFileName(ExportKind.backup, on: _on),
        'garage-backup-2026-08-22.json',
      );
    });

    test('a CSV export is a different word from a backup', () {
      // One of these restores and the other does not, and a folder holding
      // both a month apart is exactly where that matters.
      expect(
        exportFileName(ExportKind.csv, on: _on),
        'garage-export-2026-08-22.csv',
      );
    });

    test('a report is named after the car it is about', () {
      expect(
        exportFileName(ExportKind.report, on: _on, vehicleName: 'Renault Clio'),
        'renault-clio-report-2026-08-22.pdf',
      );
    });

    test('a report with no car falls back to the app name', () {
      expect(
        exportFileName(ExportKind.report, on: _on),
        'garage-report-2026-08-22.pdf',
      );
    });
  });

  group('a car name that has to survive a filesystem', () {
    String slug(String name) =>
        exportFileName(ExportKind.report, on: _on, vehicleName: name);

    test('Croatian diacritics become their bare letters', () {
      // Not stripped: "Škoda" would become "koda". Android, iOS and every
      // desktop can hold the accented form, but a name that survives a share
      // sheet, a sync folder and an email attachment cannot rely on it.
      expect(slug('Škoda Octavia'), 'skoda-octavia-report-2026-08-22.pdf');
      expect(slug('Čađavi Đuro'), 'cadavi-duro-report-2026-08-22.pdf');
      expect(slug('Žuti Ćiro'), 'zuti-ciro-report-2026-08-22.pdf');
    });

    test('a path separator cannot escape into the name', () {
      expect(slug('../../etc/passwd'), 'etc-passwd-report-2026-08-22.pdf');
    });

    test('runs of punctuation collapse to one dash', () {
      expect(slug('Golf  Mk4 (TDI)'), 'golf-mk4-tdi-report-2026-08-22.pdf');
    });

    test('a name with nothing usable in it falls back', () {
      expect(slug('🚗🚗🚗'), 'garage-report-2026-08-22.pdf');
      expect(slug('   '), 'garage-report-2026-08-22.pdf');
    });

    test('an absurdly long name is cut, not carried', () {
      final long = exportFileName(
        ExportKind.report,
        on: _on,
        vehicleName: 'a' * 200,
      );

      expect(long.length, lessThan(80));
      expect(long, endsWith('-report-2026-08-22.pdf'));
    });
  });

  test('the day is padded so names sort in the folder', () {
    expect(
      exportFileName(ExportKind.backup, on: DateTime(2026, 1, 5)),
      'garage-backup-2026-01-05.json',
    );
  });
}
