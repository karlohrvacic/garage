import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/format/month_grouping.dart';
import '../../../domain/maintenance/bundling.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../maintenance/widgets/maintenance_calendar.dart';
import '../../maintenance/widgets/reminder_rule_sheet.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/widgets/vehicle_picker.dart';
import '../providers/planner_providers.dart';
import '../../household/providers/household_providers.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  /// A month calendar of what is due existed only per vehicle, behind the
  /// vehicle page's overflow menu. "What is coming" is this screen's
  /// question, so the calendar answers it here too, for the whole garage.
  bool _calendar = false;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    _month = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
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
    final furtherOut = ref.watch(furtherOutProvider).value ?? const [];

    // The planner answers "what is coming up", and changing that answer used
    // to mean leaving for a vehicle's maintenance screen. With nothing to
    // attach a rule to, the offer would only lead to an empty picker.
    Future<void> addReminder() async {
      var vehicleId = vehicles.first.id;
      if (vehicles.length > 1) {
        final picked = await showVehiclePicker(context, vehicles);
        if (picked == null || !context.mounted) {
          return;
        }
        vehicleId = picked;
      }
      await showReminderRuleSheet(context, vehicleId);
    }

    return GarageTabScaffold(
      current: GarageTab.planner,
      // Two answers to "what is coming up" — the week runway and the visits
      // worth grouping — which a window can show at once instead of making
      // one scroll past the other.
      contentWidth: ContentWidth.wide,
      title: l10n.plannerTitle,
      actions: [
        if (vehicles.isNotEmpty)
          IconButton(
            key: const Key('planner-add-rule'),
            tooltip: l10n.plannerAddReminder,
            onPressed: addReminder,
            icon: const Icon(Icons.add_alarm_outlined),
          ),
      ],
      body: AsyncValueView<List<RunwayWeek>>(
        value: runway,
        // The runway derives from per-vehicle rules/services/fuel; invalidating
        // only the aggregate would re-await whichever leaf still caches the
        // error. Family-wide invalidation refreshes every vehicle's data.
        onRetry: () {
          ref
            ..invalidate(garageBootstrapProvider)
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
                  // Over a "Further out" card the empty state is a line,
                  // not a call to action: the page is not empty, and the
                  // filled button made a second primary above the card.
                  if (!anyItems && furtherOut.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: GarageTokens.space4,
                      ),
                      child: Text(
                        l10n.plannerEmpty,
                        style: TextStyle(color: context.tokens.muted),
                      ),
                    )
                  else if (!anyItems)
                    EmptyState(
                      message: l10n.plannerEmpty,
                      action: vehicles.isEmpty
                          ? null
                          : FilledButton.tonalIcon(
                              key: const Key('planner-add-rule-empty'),
                              onPressed: addReminder,
                              icon: const Icon(Icons.add_alarm_outlined),
                              label: Text(l10n.plannerAddReminder),
                            ),
                    )
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
            // Its own section, after the bundles: on a phone the visits
            // within twelve weeks come before what is due next year.
            if (furtherOut.isNotEmpty)
              _FurtherOut(
                items: furtherOut,
                vehicleNames: vehicleNames,
                locale: Localizations.localeOf(context).languageCode,
              ),
          ];

          final control = SegmentedButton<bool>(
            key: const Key('planner-view'),
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.maintenanceList),
                icon: const Icon(Icons.list),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.maintenanceCalendar),
                icon: const Icon(Icons.calendar_month),
              ),
            ],
            selected: {_calendar},
            onSelectionChanged: (choice) =>
                setState(() => _calendar = choice.first),
          );
          // Stretched across a phone; on a desktop window a toggle a metre
          // wide is not a toggle.
          final view = GarageBreakpoints.isDesktop(context)
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: control,
                )
              : control;
          if (_calendar) {
            final all =
                ref.watch(householdProjectionsProvider).value ?? const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(GarageTokens.space4),
                  child: view,
                ),
                Expanded(
                  child: MaintenanceCalendar(
                    projections: all,
                    vehicleNames: vehicleNames,
                    today: ref.watch(todayProvider),
                    month: _month,
                    onMonthChanged: (month) => setState(() => _month = month),
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(GarageTokens.space4),
            children: [
              view,
              const SizedBox(height: GarageTokens.space4),
              Text(
                l10n.plannerRunway,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space1),
              // Only over a list: above "Nothing due" the sentence described
              // a placement that had nothing to place.
              if (anyItems)
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
              // Tappable: a row naming a car and a job led nowhere, so a
              // garage with thirty reminders had no way from the plan to the
              // rule behind it.
              _PlannerRow(item: item, vehicleNames: vehicleNames),
          ],
        ),
      ),
    );
  }
}

/// What is due beyond the runway, by month. A reminder set for next year
/// showed nowhere on this screen; this is where it shows.
class _FurtherOut extends StatelessWidget {
  const _FurtherOut({
    required this.items,
    required this.vehicleNames,
    required this.locale,
  });

  final List<ReminderProjection> items;
  final Map<String, String> vehicleNames;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      key: const Key('planner-further-out'),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.plannerFurtherOut.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space1),
            Text(
              l10n.plannerFurtherOutNote,
              style: TextStyle(color: context.tokens.muted),
            ),
            for (final group in MonthGrouping.of(
              items,
              (item) => item.projectedDueDate,
            )) ...[
              const SizedBox(height: GarageTokens.space3),
              Text(
                DateFormat.yMMMM(locale).format(group.month),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final item in group.items)
                _PlannerRow(item: item, vehicleNames: vehicleNames),
            ],
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

/// One planned item: the car, the job, and a way into the rule behind it.
class _PlannerRow extends StatelessWidget {
  const _PlannerRow({required this.item, required this.vehicleNames});

  final ReminderProjection item;
  final Map<String, String> vehicleNames;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => context.push('/vehicles/${item.vehicleId}/maintenance'),
      borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: GarageTokens.space1),
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
            Icon(Icons.chevron_right, size: 18, color: context.tokens.muted),
          ],
        ),
      ),
    );
  }
}
