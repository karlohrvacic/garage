import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../domain/maintenance/reminder_projection.dart';
import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// Due/overdue/upcoming as a pill. Colour is semantic here — state, never
/// decoration — which is why it draws from the semantic tokens rather than the
/// accent.
class StateChip extends StatelessWidget {
  const StateChip({required this.state, super.key});

  final ReminderState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    final (color, label) = switch (state) {
      ReminderState.overdue => (tokens.danger, l10n.maintenanceStateOverdue),
      ReminderState.due => (tokens.warn, l10n.maintenanceStateDue),
      ReminderState.upcoming => (tokens.muted, l10n.maintenanceStateUpcoming),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GarageTokens.space2,
        vertical: GarageTokens.space1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GarageTokens.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
