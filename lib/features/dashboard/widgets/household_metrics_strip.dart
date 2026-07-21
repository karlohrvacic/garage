import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/dashboard_providers.dart';

/// Three fleet-level figures in muted labels with monospace values: how many
/// vehicles, what they have cost, and how frugal they are on average.
class HouseholdMetricsStrip extends ConsumerWidget {
  const HouseholdMetricsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    final vehicleCount = ref.watch(vehiclesProvider).value?.length ?? 0;
    final spend = ref.watch(fleetSpendProvider).value;
    final economy = ref.watch(fleetAverageEconomyProvider).value;

    return Padding(
      padding: const EdgeInsets.all(GarageTokens.space4),
      child: Row(
        children: [
          _Metric(
            label: l10n.vehiclesTitle,
            value: l10n.dashboardVehicleCount(vehicleCount),
          ),
          _Metric(
            label: l10n.maintenanceServiceCost,
            value: spend == null ? UnitFormat.emptyValue : format.formatMoney(spend),
          ),
          _Metric(
            label: l10n.fuelAverage,
            value: format.formatEconomy(economy),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: context.tokens.muted),
          ),
          Text(
            value,
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.titleMedium!,
            ),
          ),
        ],
      ),
    );
  }
}
