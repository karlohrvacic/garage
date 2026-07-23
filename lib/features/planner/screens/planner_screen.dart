import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/maintenance/bundling.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/planner_providers.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final runway = ref.watch(runwayProvider);
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final vehicleNames = {for (final v in vehicles) v.id: v.nickname};
    final exclusions = ref.watch(plannerExclusionsProvider);
    final bundles = ref.watch(bundlesProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plannerTitle)),
      bottomNavigationBar: const GarageBottomNav(current: GarageTab.planner),
      body: AsyncValueView<List<RunwayWeek>>(
        value: runway,
        // The runway derives from per-vehicle rules/services/fuel; invalidating
        // only the aggregate would re-await whichever leaf still caches the
        // error. Family-wide invalidation refreshes every vehicle's data.
        onRetry: () {
          ref
            ..invalidate(allVehiclesProvider)
            ..invalidate(reminderRulesProvider)
            ..invalidate(serviceEntriesProvider)
            ..invalidate(rawFuelEntriesProvider);
        },
        data: (weeks) {
          final anyItems = weeks.any((w) => w.items.isNotEmpty);
          return ListView(
            padding: const EdgeInsets.all(GarageTokens.space4),
            children: [
              Text(
                l10n.plannerRunway,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space1),
              Text(
                l10n.plannerOverdueNote,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space4),
              if (!anyItems)
                EmptyState(message: l10n.plannerEmpty)
              else
                for (final week in weeks)
                  if (week.items.isNotEmpty)
                    _WeekBand(
                      week: week,
                      format: format,
                      vehicleNames: vehicleNames,
                    ),
              if (bundles.isNotEmpty) ...[
                const SizedBox(height: GarageTokens.space6),
                Text(
                  l10n.bundleExplain,
                  style: TextStyle(color: context.tokens.muted),
                ),
                const SizedBox(height: GarageTokens.space2),
                for (final bundle in bundles)
                  _PlannerBundle(
                    bundle: bundle,
                    exclusions: exclusions,
                    vehicleNames: vehicleNames,
                    onToggle: (ruleId) => ref
                        .read(plannerExclusionsProvider.notifier)
                        .toggle(ruleId),
                  ),
              ],
              // An excluded item's row disappears with it, taking its toggle
              // along — without this the exclusion would be irreversible.
              if (exclusions.isNotEmpty)
                TextButton(
                  onPressed: () =>
                      ref.read(plannerExclusionsProvider.notifier).clear(),
                  child: Text(l10n.plannerRestoreExcluded),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekBand extends StatelessWidget {
  const _WeekBand({
    required this.week,
    required this.format,
    required this.vehicleNames,
  });

  final RunwayWeek week;
  final UnitFormat format;
  final Map<String, String> vehicleNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.plannerWeekOf(format.formatShortDate(week.start)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: GarageTokens.space2),
            for (final item in week.items)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space1,
                ),
                child: Row(
                  children: [
                    StateChip(state: item.state),
                    const SizedBox(width: GarageTokens.space2),
                    Expanded(
                      child: Text(
                        '${vehicleNames[item.vehicleId] ?? ''} · '
                        '${serviceTypeLabel(l10n, item.serviceTypeKey)}',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlannerBundle extends StatelessWidget {
  const _PlannerBundle({
    required this.bundle,
    required this.exclusions,
    required this.vehicleNames,
    required this.onToggle,
  });

  final MaintenanceBundle bundle;
  final Set<String> exclusions;
  final Map<String, String> vehicleNames;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Fold every active exclusion over the original grouping so the visit date
    // and span always describe the items still in.
    MaintenanceBundle? current = bundle;
    for (final ruleId in exclusions) {
      current = current?.exclude(ruleId);
      if (current == null) {
        break;
      }
    }
    if (current == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bundleVisitOn(
                MaterialLocalizations.of(context)
                    .formatShortDate(current.visitDate),
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final item in current.items)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${vehicleNames[item.projection.vehicleId] ?? ''} · '
                      '${serviceTypeLabel(l10n, item.projection.serviceTypeKey)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => onToggle(item.projection.ruleId),
                    child: Text(l10n.bundleExclude),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
