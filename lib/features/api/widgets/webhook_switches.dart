import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../domain/api/api_access.dart';
import '../../../domain/entities/vehicle.dart';
import '../webhook_format_labels.dart';

/// The events a webhook can be sent, one switch per group, and at least one
/// on. Shared by the add sheet and the hook's own screen so the two never
/// disagree about what the choices are.
class WebhookEventSwitches extends StatelessWidget {
  const WebhookEventSwitches({
    super.key,
    required this.chosen,
    required this.onChanged,
    this.error,
  });

  final Set<WebhookEventGroup> chosen;
  final void Function(WebhookEventGroup group, bool on) onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.apiWebhookEvents,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final group in WebhookEventGroup.values)
          SwitchListTile(
            key: Key('webhook-group-${group.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(webhookGroupLabel(l10n, group)),
            value: chosen.contains(group),
            onChanged: (on) => onChanged(group, on),
          ),
        if (error != null)
          Text(error!, style: TextStyle(color: context.tokens.danger)),
      ],
    );
  }
}

/// The cars a webhook is told about, one switch each. All on is every car,
/// which the repository stores as no list at all, so a car added later is
/// included without anyone editing the hook.
class WebhookCarSwitches extends StatelessWidget {
  const WebhookCarSwitches({
    super.key,
    required this.vehicles,
    required this.chosen,
    required this.onChanged,
    this.heading = true,
    this.error,
  });

  final List<Vehicle> vehicles;
  final Set<String> chosen;
  final void Function(String vehicleId, bool on) onChanged;

  /// Off in a sheet whose title already says "Cars".
  final bool heading;

  /// Under the switches when none is on: the drain reads an empty list as
  /// every car, so a hook for no car cannot be stored as what was chosen.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heading)
          Text(
            l10n.apiWebhookCars,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        for (final vehicle in vehicles)
          SwitchListTile(
            key: Key('webhook-car-${vehicle.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(vehicle.nickname),
            value: chosen.contains(vehicle.id),
            onChanged: (on) => onChanged(vehicle.id, on),
          ),
        if (error != null)
          Text(error!, style: TextStyle(color: context.tokens.danger)),
      ],
    );
  }
}
