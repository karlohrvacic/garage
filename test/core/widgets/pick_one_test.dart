import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/core/widgets/pick_one.dart';

const _options = [
  PickOption('fuelio', 'From Fuelio', subtitle: 'A backup file'),
  PickOption('csv', 'From a spreadsheet', icon: Icons.table_chart_outlined),
];

/// Opens the picker on a window [width] wide and returns what it answered
/// once something closes it.
Future<Future<String?> Function()> _open(
  WidgetTester tester, {
  double width = 400,
  String? title = 'Import',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  late Future<String?> answer;
  await tester.pumpWidget(
    MaterialApp(
      theme: GarageTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                answer = showPickOne(context, title: title, options: _options),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  return () => answer;
}

void main() {
  testWidgets('the row tapped is the answer', (tester) async {
    final answer = await _open(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('From a spreadsheet'));
    await tester.pumpAndSettle();

    expect(await answer(), 'csv');
  });

  testWidgets('each row says what it is for', (tester) async {
    await _open(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Import'), findsOneWidget);
    expect(find.text('A backup file'), findsOneWidget);
    expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
  });

  testWidgets('on a phone it is a sheet that a drag puts away', (tester) async {
    // Nothing in it is typed, so there is nothing a flick could lose: an entry
    // sheet turns dragging off only because it skipped the discard guard.
    final answer = await _open(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    // By its handle, where a thumb would take it.
    final top = tester.getTopLeft(find.byType(BottomSheet));
    await tester.flingFrom(
      top + const Offset(200, 12),
      const Offset(0, 600),
      2000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(await answer(), isNull);
  });

  testWidgets('on a wide window it is a dialog no wider than a form', (
    tester,
  ) async {
    // A sheet across a whole monitor reads as phone furniture left behind.
    await _open(tester, width: 1400);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    // The dialog's own surface: a Dialog widget spans the window and centres
    // the Material it draws.
    final surface = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(Material),
    );
    expect(
      tester.getSize(surface.first).width,
      lessThanOrEqualTo(GarageBreakpoints.dialogMaxWidth),
    );
  });

  testWidgets('six rows with a line each are all in view on a phone', (
    tester,
  ) async {
    // A sheet that is not scroll-controlled stops at nine sixteenths of the
    // screen, so the sixth report kind sat below the fold with nothing to say
    // it was there.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(432, 768);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: GarageTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPickOne(
                context,
                title: 'Create report',
                options: [
                  for (var i = 0; i < 6; i++)
                    PickOption(
                      i,
                      'Report $i',
                      subtitle: 'What report $i holds',
                    ),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      expect(
        find.text('Report $i').hitTestable(),
        findsOneWidget,
        reason: '$i',
      );
    }
  });

  testWidgets('a long list scrolls instead of overflowing', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: GarageTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPickOne(
                context,
                title: 'Which car?',
                options: [
                  for (var i = 0; i < 20; i++)
                    PickOption('v$i', 'Car $i', subtitle: 'ZG-$i-AB'),
                ],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Car 19'), 200);
    expect(find.text('Car 19'), findsOneWidget);
  });
}
