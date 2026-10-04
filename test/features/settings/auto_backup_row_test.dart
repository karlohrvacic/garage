import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'export_saving_test.dart' show pumpData;

/// The automatic-backup row in settings, which is where somebody looks to see
/// whether their backups are still being written.
void main() {
  final lastGood = DateTime(2026, 9, 18).millisecondsSinceEpoch;
  final failed = DateTime(2026, 10, 4, 22, 42).millisecondsSinceEpoch;

  Future<void> showRow(WidgetTester tester) async {
    final row = find.byKey(const Key('settings-auto-backup'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says when the last backup was written', (tester) async {
    SharedPreferences.setMockInitialValues({
      'backup.folderUri': 'content://tree/backups',
      'backup.lastRunAt': lastGood,
    });
    await pumpData(tester);
    await showRow(tester);

    expect(find.textContaining('last backed up'), findsOneWidget);
  });

  testWidgets('says the last one failed, rather than a date that stopped', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'backup.folderUri': 'content://tree/backups',
      'backup.lastRunAt': lastGood,
      'backup.failedAt': failed,
    });
    await pumpData(tester);
    await showRow(tester);

    expect(find.textContaining('last backed up'), findsNothing);
    expect(
      find.text('The last backup failed. Tap to choose the folder again'),
      findsOneWidget,
    );
  });

  testWidgets('leaves room for itself in Croatian once a folder is chosen', (
    tester,
  ) async {
    // "Prekini kopiranje" as a text button beside the row took all of a
    // 320-pixel phone at 1.5x, before any failure had anything to say.
    SharedPreferences.setMockInitialValues({
      'backup.folderUri': 'content://tree/backups',
      'backup.lastRunAt': lastGood,
    });
    await pumpData(
      tester,
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 1200),
    );
    await showRow(tester);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Prekini kopiranje'), findsOneWidget);
  });

  testWidgets('fits in Croatian on a narrow phone at a large font', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'backup.folderUri': 'content://tree/backups',
      'backup.failedAt': failed,
    });
    await pumpData(
      tester,
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 1200),
    );
    await showRow(tester);

    expect(find.textContaining('nije uspjela'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
