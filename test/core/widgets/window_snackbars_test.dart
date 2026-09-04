import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/window_snackbars.dart';

Future<void> pumpApp(WidgetTester tester, Size surface) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => WindowSnackBars(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('toast'))),
            child: const Text('show'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// The card itself: the SnackBar widget keeps the row, its material takes
/// the width.
Finder material() => find
    .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
    .first;

void main() {
  testWidgets('on a desktop window a snackbar is a centred card', (
    tester,
  ) async {
    // The root snackbar spanned the window, sidebar included: a sheet's
    // messenger is the root one, so no pane-level scaffold could catch it.
    await pumpApp(tester, const Size(1400, 900));

    final toast = tester.getRect(material());
    expect(toast.width, WindowSnackBars.maxWidth);
    expect(toast.left, greaterThan(240));
  });

  testWidgets('on a phone it keeps the width it had', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    final toast = tester.getRect(material());
    expect(toast.width, 400 - 32);
  });
}
