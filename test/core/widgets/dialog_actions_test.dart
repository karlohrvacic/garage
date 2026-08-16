import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/dialog_actions.dart';

void main() {
  testWidgets('when the actions stack, the one you came to press is on top', (
    tester,
  ) async {
    // A narrow dialog stacks its actions, and Material's order put Cancel
    // above the primary action: the button you opened the dialog to press
    // ended up second, under the one that abandons the job.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlertDialog(
            title: const Text('New key'),
            actionsOverflowDirection: garageActionsOverflowDirection,
            actionsOverflowAlignment: garageActionsOverflowAlignment,
            actions: [
              TextButton(
                onPressed: () {},
                child: const Text('Cancel with a long label'),
              ),
              FilledButton(
                onPressed: () {},
                child: const Text('Create with a long label'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cancelY = tester.getTopLeft(find.byType(TextButton)).dy;
    final createY = tester.getTopLeft(find.byType(FilledButton)).dy;

    expect(
      createY,
      lessThan(cancelY),
      reason: 'the primary action leads, and Cancel sits under it',
    );
  });
}
