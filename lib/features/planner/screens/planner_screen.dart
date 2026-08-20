import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/maintenance/bundling.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
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

    return GarageTabScaffold(
      current: GarageTab.planner,
      // Two answers to "what is coming up" — the week runway and the visits
      // worth grouping — which a window can show at once instead of making
      // one scroll past the other.
      contentWidth: ContentWidth.wide,
      title: l10n.plannerTitle,
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
          final sections = <Widget>[
            Padding(
              // Parts the two sections where they stack on a phone. On a
              // desktop window it is trailing space under a column, so it
              // costs nothing there.
              padding: const EdgeInsets.only(bottom: GarageTokens.space6),
              child: Column(
                key: const Key('planner-runway'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                ],
              ),
            ),
            if (bundles.isNotEmpty)
              Column(
                key: const Key('planner-bundles'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
              ),
          ];

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
              // A lone section split into columns would leave half the window
              // blank, so the runway keeps the full width until there are
              // bundles to put beside it.
              if (sections.length > 1)
                AdaptiveColumns(children: sections)
              else
                ...sections,
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
              l10n
                  .plannerWeekOf(format.formatShortDate(week.start))
                  .toUpperCase(),
              style: GarageTheme.eyebrow(context),
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
    // Whether *this* card lost anything, which is not the same as the screen
    // holding an exclusion: the one that is set may belong to another bundle.
    final trimmed = current.items.length < bundle.items.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bundleVisitOn(
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(current.visitDate),
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
                  // An icon with a tooltip, the same control the dashboard
                  // card settled on. As a word beside the row it read like a
                  // decision about the service rather than about the
                  // suggestion — and Croatian renders it "Preskoči", Skip,
                  // sitting a thumb's width from a brake fluid change.
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: l10n.bundleExclude,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onToggle(item.projection.ruleId),
                  ),
                ],
              ),
            // Only once something has been trimmed, and then it is the whole
            // reassurance the dashboard gives: the schedule is untouched.
            if (trimmed)
              Text(
                l10n.bundleExcludeHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
            const SizedBox(height: GarageTokens.space2),
            if (_singleVehicle(current) case final vehicleId?)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const Key('planner-log-visit'),
                  onPressed: () => showServiceEntrySheet(
                    context,
                    vehicleId,
                    initialServiceTypeKeys: {
                      for (final item in current!.items)
                        item.projection.serviceTypeKey,
                    },
                  ),
                  icon: const Icon(Icons.build_outlined),
                  label: Text(l10n.bundleLogVisit),
                ),
              )
            else
              Text(
                l10n.bundleOneVehicleOnly,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  /// The one vehicle these items are on, or null if they span several.
  ///
  /// A service entry belongs to a single car, so a bundle across two of them
  /// has nothing to log against; saying so is better than a button that would
  /// have to guess.
  static String? _singleVehicle(MaintenanceBundle bundle) {
    final ids = bundle.items.map((item) => item.projection.vehicleId).toSet();
    return ids.length == 1 ? ids.single : null;
  }
}
