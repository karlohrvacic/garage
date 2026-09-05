import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../domain/entities/vehicle.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/dashboard_providers.dart';
import '../../household/providers/household_providers.dart';

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
          onRetry: () => ref.invalidate(garageBootstrapProvider),
          data: (list) {
            // Spend and economy are derived and settle a beat after the vehicle
            // list; a placeholder for the moment they resolve is fine.
            final spend = ref.watch(fleetSpendProvider).value;
            final economy = ref.watch(fleetAverageEconomyProvider).value;
            // Thirds of a phone; on a desktop window three figures spread
            // across a thousand pixels read as a table with no rows, so
            // there they sit together at their own width.
            final desktop = GarageBreakpoints.isDesktop(context);
            Widget cell(Widget child) => desktop
                ? SizedBox(width: 200, child: child)
                : Expanded(child: child);
            return Row(
              // Croatian labels fill their third of the row; without a gap
              // "UKUPNO POTROŠENO" ran straight into "PROSJEK".
              spacing: GarageTokens.space3,
              children: [
                cell(
                  ClusterReadout(
                    dense: true,
                    label: l10n.vehiclesTitle,
                    value: l10n.dashboardVehicleCount(list.length),
                  ),
                ),
                cell(
                  ClusterReadout(
                    dense: true,
                    // Everything ever logged against every active
                    // vehicle, not a period. It read simply "Cost"
                    // — a form-field label borrowed as a heading —
                    // which invited reading it as this year's.
                    label: l10n.dashboardTotalSpent,
                    value: spend == null
                        ? UnitFormat.emptyValue
                        : format.formatMoney(spend),
                  ),
                ),
                cell(
                  ClusterReadout(
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
