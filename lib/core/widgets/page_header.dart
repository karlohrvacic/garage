import 'package:flutter/material.dart';

import '../theme/garage_tokens.dart';

/// A page's title and actions, rendered inside the content.
///
/// Desktop chrome, replacing the app bar above [GarageBreakpoints.desktop]. A
/// persistent top bar with a back arrow is how a phone app looks, and on a
/// window with a sidebar it is both redundant (the sidebar is the navigation)
/// and misleading (a top-level page has nowhere to go back to).
///
/// The title is set at content scale rather than app-bar scale, so a page reads
/// as a document with a heading instead of a phone screen with a bar on top.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final List<Widget> actions;

  /// Supplied only by screens that were pushed onto something. A top-level
  /// destination leaves this null and gets no back affordance.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final materialL10n = MaterialLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space6,
        GarageTokens.space4,
        GarageTokens.space4,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              tooltip: materialL10n.backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: GarageTokens.space2),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
