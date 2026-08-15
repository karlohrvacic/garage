import 'package:flutter/material.dart';

import 'adaptive.dart';
import 'page_header.dart';

/// Scaffold for a screen that was pushed onto another, the counterpart to
/// [GarageTabScaffold] for the top-level destinations.
///
/// Adapts the same way: an app bar on a phone, a heading inside the content on
/// a desktop window. Unlike a tab, a pushed page keeps a way back, because here
/// back goes somewhere the user actually came from.
class GaragePageScaffold extends StatelessWidget {
  const GaragePageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
    this.bottom,
    this.contentWidth = ContentWidth.reading,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  /// A tab bar or similar, shown under the title in both presentations.
  final PreferredSizeWidget? bottom;

  /// How much of a desktop window the content should use. Reading width by
  /// default: most pushed screens are forms or two-ended list rows, where the
  /// extra space only pushes a row's two halves apart.
  final ContentWidth contentWidth;

  @override
  Widget build(BuildContext context) {
    if (!GarageBreakpoints.isWide(context)) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions, bottom: bottom),
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: AdaptiveContent(
        width: contentWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: title,
              actions: actions,
              // Only offered when there is something to go back to; a page
              // opened directly by URL on the web has an empty stack.
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            ?bottom,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
