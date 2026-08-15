import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../domain/entities/vehicle.dart';
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

    final vehicles = ref.watch(vehiclesProvider);

    return Padding(
      padding: const EdgeInsets.all(GarageTokens.space4),
      // A floor rather than a fixed height: the row has to keep its shape
      // while the figures load, but a large accessibility text scale needs
      // room to grow into instead of clipping the numbers.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: AsyncValueView<List<Vehicle>>(
          value: vehicles,
          onRetry: () => ref.invalidate(allVehiclesProvider),
          data: (list) {
            // Spend and economy are derived and settle a beat after the vehicle
            // list; a placeholder for the moment they resolve is fine.
            final spend = ref.watch(fleetSpendProvider).value;
            final economy = ref.watch(fleetAverageEconomyProvider).value;
            return Row(
              children: [
                Expanded(
                  child: ClusterReadout(
                    dense: true,
                    label: l10n.vehiclesTitle,
                    value: l10n.dashboardVehicleCount(list.length),
                  ),
                ),
                Expanded(
                  child: ClusterReadout(
                    dense: true,
                    label: l10n.maintenanceServiceCost,
                    value: spend == null
                        ? UnitFormat.emptyValue
                        : format.formatMoney(spend),
                  ),
                ),
                Expanded(
                  child: ClusterReadout(
                    dense: true,
                    label: l10n.fuelAverage,
                    value: format.formatEconomy(economy),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
