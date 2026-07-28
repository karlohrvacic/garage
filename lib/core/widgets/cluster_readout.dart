import 'package:flutter/material.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// A dashboard-style metric readout: eyebrow label over a large mono value.
/// In dark mode emphasized readouts light up in dash amber; quiet screens pass
/// `emphasized: false` and stay foreground-colored.
class ClusterReadout extends StatelessWidget {
  const ClusterReadout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.emphasized = true,
    this.dense = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool emphasized;

  /// Compact readout for strips showing several side by side.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final lit = emphasized && Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: GarageTheme.eyebrow(context)),
        const SizedBox(height: GarageTokens.space1),
        Text.rich(
          TextSpan(
            text: value,
            style: GarageTheme.numeric(
              dense ? textTheme.titleMedium! : textTheme.headlineSmall!,
            ).copyWith(color: lit ? tokens.accent : tokens.fg),
            children: [
              if (unit != null)
                TextSpan(text: ' ${unit!}', style: textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}
