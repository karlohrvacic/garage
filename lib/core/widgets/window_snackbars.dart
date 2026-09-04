import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sizes every snackbar to the window it is shown in.
///
/// Sheets and dialogs are modal routes under the root navigator, so their
/// `ScaffoldMessenger.of(context)` is the app's root messenger whatever
/// scaffold the page below uses; a messenger scoped to the content pane never
/// sees them. The root snackbar spans the window, sidebar included. A floating
/// snackbar with a width is centred instead, and a width that follows the
/// window keeps it off the sidebar on a desktop and edge to edge on a phone.
class WindowSnackBars extends StatelessWidget {
  const WindowSnackBars({required this.child, super.key});

  final Widget child;

  /// The most a snackbar takes on a wide window.
  static const double maxWidth = 560;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(maxWidth, constraints.maxWidth - 32);
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            snackBarTheme: theme.snackBarTheme.copyWith(
              behavior: SnackBarBehavior.floating,
              width: width,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
