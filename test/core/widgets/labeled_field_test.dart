import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/labeled_field.dart';

void main() {
  testWidgets('a labelled field in a dialog is only as tall as its content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AlertDialog(
            title: Text('New key'),
            content: LabeledField(label: 'What is it for?', child: TextField()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final height = tester.getSize(find.byType(LabeledField)).height;

    expect(
      height,
      lessThan(200),
      reason:
          'a label and one input stretched to the full window height, leaving '
          'a dialog with a field at the top and its buttons far below',
    );
  });
}
