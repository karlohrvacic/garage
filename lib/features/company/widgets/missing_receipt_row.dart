import 'package:flutter/material.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';

/// One entry with no receipt, as the car's card and the console list both
/// show it: what and when on one line, the amount under it, whatever the
/// caller adds under that, and the button on a row of its own. A trailing
/// button beside a Croatian label at a large font is wider than a narrow
/// phone.
class MissingReceiptRow extends StatelessWidget {
  const MissingReceiptRow({
    required this.title,
    required this.amount,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
    this.detail,
    super.key,
  });

  final String title;
  final String amount;

  /// A line under the amount: the console names the driver here.
  final Widget? detail;

  final String actionLabel;
  final Key actionKey;

  /// Null when there is nothing to offer, and [detail] says why.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.bodyMedium),
          Text(amount, style: GarageTheme.numeric(textTheme.bodyMedium!)),
          ?detail,
          if (onAction case final action?) ...[
            const SizedBox(height: GarageTokens.space2),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                style: GarageTheme.inlineButton,
                key: actionKey,
                onPressed: action,
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
