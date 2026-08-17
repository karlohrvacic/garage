import 'package:flutter/material.dart';

import 'adaptive.dart';
import 'garage_bottom_nav.dart';
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

    // The sidebar stays. These pages are pushed, but a desktop window that
    // loses its navigation the moment you open Statistics leaves the browser's
    // back button as the only way out, which is a phone's model on a screen
    // with room for better. No tab is marked current, because none of them is.
    return Scaffold(
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          const GarageNavigationRail(current: null),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdaptiveContent(
                  width: contentWidth,
                  child: PageHeader(
                    title: title,
                    actions: actions,
                    // Only offered when there is something to go back to; a
                    // page opened directly by URL on the web has an empty
                    // stack.
                    onBack: Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                ),
                // Outside the column on purpose. A tab strip belongs to the
                // surface it switches, so it runs the width of the pane along
                // with its divider — the same edge-to-edge strip a phone gets
                // from the app bar. Held to the text column it read as a
                // control floating mid-page, above a rule that stopped short
                // of both sides.
                ?bottom,
                Expanded(
                  child: AdaptiveContent(width: contentWidth, child: body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
