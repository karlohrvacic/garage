import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/sync/realtime_sync.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/gauge_arc.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/entities/vehicle_transfer.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../fuel/tank_range_display.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/auto_backup_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/widgets/vehicle_picker.dart';
import '../providers/dashboard_providers.dart';
import '../../costs/cost_category_labels.dart';
import '../../income/income_category_labels.dart';
import '../../maintenance/service_type_labels.dart' as service_labels;
import '../../../domain/maintenance/reminder_projection.dart';
import '../../timeline/providers/timeline_providers.dart';
import '../../fuel/widgets/fuel_entry_sheet.dart';
import '../../maintenance/widgets/reminder_rule_sheet.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../../income/widgets/income_entry_sheet.dart';
import '../../odometer/widgets/odometer_entry_sheet.dart';
import '../../trips/widgets/trip_entry_sheet.dart';
import '../../settings/data/fuelio_import_action.dart';
import '../../settings/data/sample_data_action.dart';
import '../widgets/bundle_card.dart';
import '../providers/what_next_providers.dart';
import '../widgets/household_metrics_strip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../sync/widgets/pending_sync_banner.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    // Decision 74 replaced a tab bar over three spinners with one quiet
    // "Opening your garage…" screen, because a screen of spinners reads as a
    // broken app. That was right about spinners and is superseded here by the
    // option it did not weigh: the shell, with the dashboard's own shape drawn
    // in placeholders. Nothing spins, nothing is centred in an empty window,
    // and — because the outline is the layout — nothing moves when the data
    // arrives.
    //
    // First load only: a refresh keeps the previous value and must not swap
    // the whole screen for the skeleton.
    final householdState = ref.watch(currentHouseholdProvider);
    if (householdState.isLoading && !householdState.hasValue) {
      return GarageTabScaffold(
        current: GarageTab.dashboard,
        contentWidth: ContentWidth.wide,
        title: l10n.dashboardTitle,
        // No button: there is nothing yet to log a fill-up against, and an
        // action that cannot work is worse than one that is not offered.
        body: const DashboardSkeleton(),
      );
    }

    // Holds the realtime subscription open for as long as the dashboard — the
    // app's landing screen — is mounted, so a household's devices stay in sync.
    ref.watch(realtimeSyncProvider);

    // Re-plan local reminders whenever what's due changes (mobile only).
    ref.listen(bundlesProvider, (_, next) {
      if (next.hasValue) {
        syncNotifications(ref, l10n);
      }
    });
    ref.listen(householdProjectionsProvider, (_, next) {
      if (next.hasValue) {
        syncNotifications(ref, l10n);
      }
    });
    // Through a listener rather than from build, which must stay pure. The
    // schedule itself is what stops this doing anything on the second call —
    // a backup is written at most once a day, whatever wakes this up.
    //
    // The messenger is captured now, synchronously, rather than reading
    // `context` after the await below: this widget can be gone by the time a
    // backup finishes writing, and a `context` read at that point belongs to
    // whatever replaced it. `ScaffoldMessengerState` outlives the widget that
    // captured it, which `context` does not.
    ref.listen(allVehiclesProvider, (_, next) {
      if (next.hasValue) {
        final messenger = ScaffoldMessenger.of(context);
        runAutoBackupIfDue(ref).then((backedUp) {
          if (backedUp) {
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.settingsAutoBackupJustRan)),
            );
          }
        });
      }
    });

    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    final topBundle = ref.watch(topBundleProvider).value;
    final projections =
        ref.watch(householdProjectionsProvider).value ?? const [];
    final today = DateMath.dateOnly(ref.watch(todayProvider));

    // What is due *soon*, not simply what is due next. Every rule on every
    // vehicle resolves to a date, so the five soonest on a garage in good
    // order were a registration eleven months out and an oil change fourteen
    // — real, dated, and nothing anybody can act on. Three months is far
    // enough ahead to book something and near enough to be worth the room.
    //
    // Anything already late stays whatever its date says: an item overdue by
    // a year is the most actionable thing on the screen, not the least.
    final horizon = DateTime(today.year, today.month, today.day + 90);
    final dueSoon = [
      for (final projection in projections)
        if (projection.state == ReminderState.overdue ||
            !projection.projectedDueDate.isAfter(horizon))
          projection,
    ];

    return GarageTabScaffold(
      current: GarageTab.dashboard,
      // A dashboard is the case for using the window: cards in columns, not a
      // reading column of stacked cards on a 1500px monitor.
      contentWidth: ContentWidth.wide,
      title: l10n.dashboardTitle,
      // On a desktop window the sidebar lists all three; the icons were the
      // same links a second time, unlabelled.
      actions: GarageBreakpoints.isDesktop(context)
          ? const []
          : [
              IconButton(
                icon: const Icon(Icons.local_gas_station_outlined),
                tooltip: l10n.stationsTitle,
                onPressed: () => context.push('/stations'),
              ),
              IconButton(
                icon: const Icon(Icons.calculate_outlined),
                tooltip: l10n.calculatorTitle,
                onPressed: () => context.push('/calculator'),
              ),
              IconButton(
                icon: const Icon(Icons.query_stats),
                tooltip: l10n.statsTitle,
                onPressed: () => context.push('/stats'),
              ),
            ],
      // Logging a fill-up used to mean Vehicles, the car, the fuel log, then a
      // button: four taps for the thing done most often, and an unscheduled
      // service was buried deeper still. This is one tap from the app's
      // landing screen. Hidden when there is no car, since there would be
      // nothing to log it against.
      floatingActionButton: ref.watch(vehiclesProvider).value?.isEmpty ?? true
          ? null
          : FloatingActionButton(
              key: const Key('dashboard-add'),
              onPressed: () => _showQuickAdd(context, ref),
              child: const Icon(Icons.add),
            ),
      body: AsyncValueView<List<Vehicle>>(
        value: ref.watch(vehiclesProvider),
        // The same outline the household gate above shows, so crossing from
        // one to the other is not a second wait with a different appearance.
        loading: () => const DashboardSkeleton(),
        onRetry: () {
          ref
            ..invalidate(garageBootstrapProvider)
            ..invalidate(currentHouseholdProvider);
        },
        // A brand-new household lands here first. "Nothing here yet" told
        // them nothing about what to do next.
        empty: () => SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Named even when empty: creating a second garage switches
              // into it, and a nameless empty dashboard is what "every car
              // I own has been deleted" looks like.
              if (ref.watch(currentHouseholdProvider).value case final it?)
                Padding(
                  padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                  child: _GarageRow(name: it.name),
                ),
              const _GettingStarted(hasVehicle: false),
            ],
          ),
        ),
        data: (vehicles) {
          final vehicleNames = {for (final v in vehicles) v.id: v.nickname};
          // The AsyncValue itself, not `.value ?? []`. Collapsing the two told
          // a garage with four years of history to log its first fill-up for
          // as long as the timeline took to arrive — which is exactly the
          // confusion `AsyncValueView` says in its own docstring it exists to
          // prevent, and this screen was reaching around it.
          final history = ref.watch(timelineProvider);
          final timeline = history.value ?? const <TimelineItem>[];
          final whatNext = ref.watch(whatNextLocalProvider);
          final hasFuel = timeline.any((it) => it.kind == TimelineKind.fuel);
          final hasRule = projections.isNotEmpty;
          // Both facts have to be known before a row is shown: an errored or
          // still-loading projection fetch is not "no reminders yet".
          final stepsKnown =
              history.hasValue &&
              ref.watch(householdProjectionsProvider).hasValue;
          // A registration eleven months out is not news; the fill-up logged
          // yesterday is. Leading with a deadline nobody can act on pushed
          // what the household actually did below the fold, so what is due
          // takes the top only when it is pressing — inside the notice
          // window, or already past — and otherwise follows recent activity.
          final pressing = projections.any(
            (it) =>
                it.state == ReminderState.due ||
                it.state == ReminderState.overdue,
          );
          final dueSection = <Widget>[
            if (dueSoon.isNotEmpty)
              Column(
                key: const Key('dashboard-due'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GarageTokens.space4,
                      GarageTokens.space4,
                      GarageTokens.space4,
                      GarageTokens.space2,
                    ),
                    child: Text(
                      l10n.dashboardDueSoonest.toUpperCase(),
                      style: GarageTheme.eyebrow(context),
                    ),
                  ),
                  for (final projection in dueSoon.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GarageTokens.space4,
                        vertical: GarageTokens.space1,
                      ),
                      child: Card(
                        child: ListTile(
                          leading: GaugeArc(
                            fraction: projection.dueness(today),
                            size: 40,
                          ),
                          title: Text(
                            serviceTypeLabel(l10n, projection.serviceTypeKey),
                          ),
                          subtitle: Text(
                            [
                              vehicleNames[projection.vehicleId] ?? '',
                              format.formatDate(
                                projection.projectedDueDate.isBefore(today)
                                    ? today
                                    : projection.projectedDueDate,
                              ),
                              // A rule with a distance interval and no
                              // distance date: the rate is unmeasured and
                              // the calendar is doing the work.
                              if (projection.dueOdometerKm != null &&
                                  projection.dateFromDistance == null)
                                l10n.dashboardDueByDateOnly,
                              // A date the odometer decided rests on a
                              // driving rate; without it the date read as
                              // fact and could not be corrected.
                              if (projection.dateFromDistance != null &&
                                  projection.dateFromDistance ==
                                      projection.projectedDueDate)
                                ...switch (ref.watch(
                                  drivingRateProvider(projection.vehicleId),
                                )) {
                                  AsyncData(value: final rate?) => [
                                    l10n.dashboardDueByDistance(
                                      format.formatDailyDistance(rate),
                                    ),
                                  ],
                                  AsyncData(value: null) => [
                                    l10n.dashboardDueByDistanceAssumed(
                                      format.formatDailyDistance(
                                        ReminderProjector.fallbackKmPerDay,
                                      ),
                                    ),
                                  ],
                                  // Not yet known: no segment, rather than
                                  // "assuming" for a frame on a car with
                                  // years of readings.
                                  _ => const <String>[],
                                },
                            ].join(' · '),
                          ),
                          onTap: () => context.push(
                            '/vehicles/${projection.vehicleId}/maintenance',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ];
          final recentSection = <Widget>[
            if (timeline.isNotEmpty)
              Padding(
                key: const Key('dashboard-recent'),
                padding: const EdgeInsets.fromLTRB(
                  GarageTokens.space4,
                  GarageTokens.space4,
                  GarageTokens.space4,
                  GarageTokens.space1,
                ),
                child: _RecentActivityCard(
                  items: timeline.take(4).toList(),
                  vehicleNames: vehicleNames,
                  format: format,
                ),
              ),
          ];
          final vehicleSection = <Widget>[
            Column(
              key: const Key('dashboard-vehicles'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final vehicle in vehicles)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GarageTokens.space4,
                      vertical: GarageTokens.space1,
                    ),
                    child: Card(
                      child: ListTile(
                        title: Text(vehicle.nickname),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ?switch ((
                              ref
                                  .watch(currentOdometerProvider(vehicle.id))
                                  .value,
                              tankRangeDistance(
                                ref.watch(tankRangeProvider(vehicle.id)).value,
                                format,
                              ),
                            )) {
                              (null, _) => null,
                              // The range rides along with the odometer
                              // rather than taking a line of its own: it is
                              // the same fact — where this car is — one
                              // reading behind and one reading ahead.
                              (final int km, final String? range) => Text(
                                [
                                  format.formatDistance(
                                    km.toDouble(),
                                    decimals: 0,
                                  ),
                                  if (range != null)
                                    '≈$range ${l10n.tankRangeLeft}',
                                ].join(' · '),
                                style: GarageTheme.numeric(
                                  Theme.of(context).textTheme.labelSmall!,
                                ),
                              ),
                            },
                            // The reward for setting a reminder, where the
                            // card asked for it: a rule a year out was
                            // invisible on the home screen and read as a
                            // save that failed.
                            ?switch (_nextUp(projections, vehicle.id)) {
                              null => null,
                              final next => Text(
                                key: const Key('vehicle-next-up'),
                                // A past date under "Next" reads as a typo;
                                // overdue says overdue.
                                next.state == ReminderState.overdue
                                    ? l10n.dashboardOverdueNow(
                                        serviceTypeLabel(
                                          l10n,
                                          next.serviceTypeKey,
                                        ),
                                      )
                                    : l10n.dashboardNextUp(
                                        serviceTypeLabel(
                                          l10n,
                                          next.serviceTypeKey,
                                        ),
                                        format.formatShortDate(
                                          next.projectedDueDate,
                                        ),
                                      ),
                                style: TextStyle(
                                  color: next.state == ReminderState.overdue
                                      ? context.tokens.danger
                                      : context.tokens.muted,
                                ),
                              ),
                            },
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.fuelAdd,
                              icon: const Icon(Icons.local_gas_station),
                              // The sheet, like the same icon on the
                              // checklist: "pump = log a fill" broke on the
                              // second use when this one opened the log.
                              onPressed: () => _runQuickAction(
                                context,
                                _QuickAction.fuel,
                                vehicle.id,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.quickAddService,
                              icon: const Icon(Icons.build_outlined),
                              onPressed: () => _runQuickAction(
                                context,
                                _QuickAction.service,
                                vehicle.id,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => context.push('/vehicles/${vehicle.id}'),
                      ),
                    ),
                  ),
              ],
            ),
          ];
          return RefreshIndicator(
            // Family-wide invalidation: the metrics strip and due list derive
            // from per-vehicle fuel/service/rule providers, and a pull that
            // left those cached would refresh almost nothing.
            onRefresh: () async {
              ref
                ..invalidate(garageBootstrapProvider)
                ..invalidate(reminderRulesProvider)
                ..invalidate(serviceEntriesProvider)
                ..invalidate(rawFuelEntriesProvider);
              // Hold the spinner until the refetch lands; a failure is already
              // rendered by the providers' own error states.
              try {
                await ref.read(householdProjectionsProvider.future);
              } on Object {
                // Ignored: the surfaces watching the provider show the error.
              }
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: GarageTokens.fabClearance),
              children: [
                // The strip spans the full width; everything below it flows
                // into two columns on a desktop window and stacks on a phone.
                const _HandedOverNotices(),
                // The garage's name, and a way into it. The people you share
                // the cars with were three taps behind the word "Settings",
                // for an app whose whole premise is sharing — and the desktop
                // sidebar header has been tappable all along.
                if (ref.watch(currentHouseholdProvider).value case final it?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GarageTokens.space4,
                      GarageTokens.space4,
                      GarageTokens.space4,
                      0,
                    ),
                    child: _GarageRow(name: it.name),
                  ),
                // Above everything, because an entry that is safe on the
                // phone and invisible in the app is the same thing as lost to
                // whoever typed it.
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    GarageTokens.space3,
                    GarageTokens.space4,
                    0,
                  ),
                  child: PendingSyncBanner(),
                ),
                const HouseholdMetricsStrip(),
                // A checklist, not an empty state: it used to vanish with the
                // first timeline entry, so whoever logged fuel first was never
                // told to set a reminder. Each row goes when its step is done;
                // the card goes when all are, or when it is put away.
                AdaptiveColumns(
                  children: [
                    // Inside the columns, so on a desktop window it is a card
                    // in the left column rather than a band across the page.
                    if (stepsKnown &&
                        !whatNext.hidden &&
                        (!hasFuel || !hasRule || !whatNext.tourOpened))
                      Padding(
                        padding: const EdgeInsets.all(GarageTokens.space4),
                        child: _GettingStarted(
                          hasVehicle: true,
                          showFuel: !hasFuel,
                          showReminder: !hasRule,
                          showTour: !whatNext.tourOpened,
                        ),
                      ),
                    // Nothing at all when there is nothing to bundle. This
                    // used to hold the first slot on the dashboard to announce
                    // an absence on every visit — the same thing decision 65
                    // moved the due list for, and which this had been left out
                    // of. Bundling is discovered the first time a real bundle
                    // appears, which is when the idea means anything.
                    if (topBundle case final bundle?)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: GarageTokens.space4,
                        ),
                        child: BundleCard(
                          bundle: bundle,
                          vehicleNames: vehicleNames,
                        ),
                      ),
                    // The cars come first: an overview of what the garage
                    // holds, and each row carries its own way straight into a
                    // fill-up. Recent activity follows, and what is due sits
                    // under both unless something is actually pressing — in
                    // which case it goes above everything.
                    ...(pressing
                        ? [...dueSection, ...vehicleSection, ...recentSection]
                        : [...vehicleSection, ...recentSection, ...dueSection]),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Compact last-entries feed; tapping it opens the Timeline tab.
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.items,
    required this.vehicleNames,
    required this.format,
  });

  final List<TimelineItem> items;
  final Map<String, String> vehicleNames;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
        onTap: () => context.go('/timeline'),
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dashboardRecent.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              const SizedBox(height: GarageTokens.space2),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: GarageTokens.space1,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        switch (item.kind) {
                          TimelineKind.fuel => Icons.local_gas_station_outlined,
                          TimelineKind.service => Icons.build_outlined,
                          TimelineKind.cost => Icons.receipt_long_outlined,
                          TimelineKind.odometer => Icons.speed_outlined,
                          TimelineKind.trip => Icons.route_outlined,
                          TimelineKind.income => Icons.savings_outlined,
                        },
                        size: 16,
                        color: context.tokens.muted,
                      ),
                      const SizedBox(width: GarageTokens.space2),
                      Expanded(
                        child: Text(
                          // With more than one car the row has to say which:
                          // "Fuel · Sep 4" was anybody's.
                          (vehicleNames.length > 1 &&
                                      vehicleNames[item.vehicleId] != null
                                  ? '${vehicleNames[item.vehicleId]} · '
                                  : '') +
                              switch (item.kind) {
                                TimelineKind.fuel => l10n.fuelTitle,
                                TimelineKind.service =>
                                  item.serviceTypeKeys
                                      .map(
                                        (key) => service_labels
                                            .serviceTypeLabel(l10n, key),
                                      )
                                      .join(', '),
                                TimelineKind.cost => costCategoryLabel(
                                  l10n,
                                  item.costCategory ?? '',
                                ),
                                TimelineKind.odometer => l10n.odometerTitle,
                                TimelineKind.trip => l10n.tripsTitle,
                                TimelineKind.income => incomeCategoryLabel(
                                  l10n,
                                  item.costCategory ?? '',
                                ),
                              },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        [
                          format.formatShortDate(item.date),
                          if (item.amount != null)
                            format.formatMoney(item.amount),
                        ].join(' · '),
                        style: GarageTheme.numeric(
                          Theme.of(context).textTheme.labelSmall!,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Offers everything a household records, and asks which car only when there
/// is more than one: a single-car household should never be made to answer a
/// question with one possible answer.
///
/// Ordered by how often it is used, not by how the schema is arranged: fuel is
/// weekly, a service is a few times a year, and selling the car happens once.
Future<void> _showQuickAdd(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  // Active cars only, and this is the whole reason to say so: an archived
  // vehicle has left the household, so it is not something anybody is filling
  // up. Reading the full list made the + button ask "which car?" in a garage
  // with one car and one sold one, and offered the sold one as an answer —
  // while the vehicle row's own shortcut, four hundred lines down, had always
  // read the active list. The button that decides whether to show this sheet
  // reads the active list too, so an all-archived garage never gets here.
  final vehicles = await ref.read(vehiclesProvider.future);
  if (vehicles.isEmpty || !context.mounted) {
    return;
  }

  final action = await showModalBottomSheet<_QuickAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        // Room under the last row: "More", and Income once it is open, sat
        // on the edge of the screen.
        padding: const EdgeInsets.only(bottom: GarageTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The three things that cost money, as tiles: they are what the
            // button is pressed for nine times in ten. Seven equal rows made
            // someone read past Income and Add reminder to find Fuel up.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GarageTokens.space4,
                GarageTokens.space4,
                GarageTokens.space4,
                GarageTokens.space2,
              ),
              child: Row(
                spacing: GarageTokens.space3,
                children: [
                  _QuickTile(
                    icon: Icons.local_gas_station_outlined,
                    label: l10n.quickAddFuel,
                    onTap: () => Navigator.of(context).pop(_QuickAction.fuel),
                  ),
                  _QuickTile(
                    icon: Icons.build_outlined,
                    label: l10n.quickAddService,
                    onTap: () =>
                        Navigator.of(context).pop(_QuickAction.service),
                  ),
                  _QuickTile(
                    icon: Icons.receipt_long_outlined,
                    label: l10n.quickAddCost,
                    onTap: () => Navigator.of(context).pop(_QuickAction.cost),
                  ),
                ],
              ),
            ),
            ExpansionTile(
              key: const Key('quick-add-more'),
              title: Text(l10n.quickAddMore),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                // Then the ones with nothing to pay: a reading and a trip are what
                // you log when there was no transaction to log.
                ListTile(
                  leading: const Icon(Icons.speed_outlined),
                  title: Text(l10n.quickAddOdometer),
                  onTap: () => Navigator.of(context).pop(_QuickAction.odometer),
                ),
                ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: Text(l10n.quickAddTrip),
                  onTap: () => Navigator.of(context).pop(_QuickAction.trip),
                ),
                // The interval, which reminders and the whole planner are built on,
                // was six taps deep and absent from here entirely — so the one thing
                // that makes the app work was the hardest thing in it to reach.
                ListTile(
                  leading: const Icon(Icons.event_repeat_outlined),
                  title: Text(l10n.quickAddInterval),
                  onTap: () => Navigator.of(context).pop(_QuickAction.interval),
                ),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: Text(l10n.quickAddIncome),
                  onTap: () => Navigator.of(context).pop(_QuickAction.income),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) {
    return;
  }

  var vehicleId = vehicles.first.id;
  if (vehicles.length > 1) {
    final picked = await showVehiclePicker(context, vehicles);
    if (picked == null || !context.mounted) {
      return;
    }
    vehicleId = picked;
  }

  await _runQuickAction(context, action, vehicleId);
}

/// Opens the sheet for [action] against [vehicleId].
///
/// Split out of the quick-add flow because the empty-state card needs the same
/// two of these without the sheet that asks which action and which vehicle.
Future<void> _runQuickAction(
  BuildContext context,
  _QuickAction action,
  String vehicleId,
) async {
  switch (action) {
    case _QuickAction.fuel:
      await showFuelEntrySheet(context, vehicleId);
    case _QuickAction.service:
      await showServiceEntrySheet(context, vehicleId);
    case _QuickAction.cost:
      await showCostEntrySheet(context, vehicleId);
    case _QuickAction.odometer:
      await showOdometerEntrySheet(context, vehicleId);
    case _QuickAction.trip:
      await showTripEntrySheet(context, vehicleId);
    case _QuickAction.income:
      await showIncomeEntrySheet(context, vehicleId);
    case _QuickAction.interval:
      await showReminderRuleSheet(context, vehicleId);
  }
}

enum _QuickAction { fuel, service, cost, odometer, trip, income, interval }

/// What a garage with nothing in it can actually do next.
///
/// This was a three-step checklist, and it was mostly scenery: only the first
/// step was tappable, and the other two hard-coded `done: false`, so they
/// could never tick however much you logged. It promised a walkthrough and
/// delivered one link.
///
/// It now offers the ways a vehicle actually gets into a garage — by hand,
/// from Fuelio, from any other app's CSV, or handed over by its previous
/// owner — because three of those were buried in Settings, which is the last
/// place someone with an empty screen thinks to look.
class _GettingStarted extends ConsumerWidget {
  const _GettingStarted({
    required this.hasVehicle,
    this.showFuel = true,
    this.showReminder = true,
    this.showTour = true,
  });

  final bool hasVehicle;
  final bool showFuel;
  final bool showReminder;
  final bool showTour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (hasVehicle ? l10n.gettingStartedNext : l10n.gettingStarted)
                  .toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
            if (hasVehicle) ...[
              // A garage with a vehicle and no history has different work to
              // do, and both of these open the thing they name rather than
              // describing it.
              if (showFuel)
                _Step(
                  label: l10n.gettingStartedFuel,
                  icon: Icons.local_gas_station_outlined,
                  onTap: () => _firstEntry(context, ref, _QuickAction.fuel),
                ),
              // The *interval* sheet, not the service sheet. This step says
              // "set what it needs, and when", and pointing it at the
              // log-a-past-service form meant a new user did exactly what the
              // card asked and still had no rules — leaving Due soonest, the
              // planner runway and bundling all empty, since every one of them
              // is derived from reminder rules.
              if (showReminder)
                _Step(
                  label: l10n.gettingStartedReminder,
                  icon: Icons.event_repeat_outlined,
                  onTap: () => _firstInterval(context, ref),
                ),
              if (showTour)
                _Step(
                  label: l10n.gettingStartedTour,
                  icon: Icons.explore_outlined,
                  onTap: () {
                    ref.read(whatNextLocalProvider.notifier).markTourOpened();
                    context.push('/tour');
                  },
                ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('what-next-hide'),
                  onPressed: () =>
                      ref.read(whatNextLocalProvider.notifier).hide(),
                  child: Text(l10n.gettingStartedHide),
                ),
              ),
            ] else ...[
              // One primary action. Five equal rows made a first-timer read
              // and reject four paths before doing the obvious one.
              FilledButton.icon(
                key: const Key('first-vehicle'),
                onPressed: () => context.push('/vehicles/new'),
                icon: const Icon(Icons.add),
                label: Text(l10n.gettingStartedFirstVehicle),
              ),
              const SizedBox(height: GarageTokens.space2),
              _Step(
                label: l10n.gettingStartedImport,
                icon: Icons.upload_file_outlined,
                onTap: () => _chooseImport(context, ref),
              ),
              // The receiving half of a transfer. Someone who has just bought
              // a car is holding a code and no vehicle, which is precisely
              // this screen.
              _Step(
                label: l10n.gettingStartedTransfer,
                icon: Icons.swap_horiz_outlined,
                onTap: () => context.push('/transfer'),
              ),
              _Step(
                label: l10n.gettingStartedTour,
                icon: Icons.explore_outlined,
                onTap: () => context.push('/tour'),
              ),
              const SizedBox(height: GarageTokens.space3),
              Text(
                l10n.gettingStartedSample,
                style: TextStyle(color: context.tokens.muted),
              ),
              // Named here, so loadable here. The line used to be inert prose
              // pointing at a Settings row three taps away, which is the worst
              // moment in the app to send someone hunting.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ref.watch(sampleDataLoadingProvider)
                    // Takes the button's place rather than sitting beside it:
                    // there is nothing to press while it runs, and a button
                    // that still looks pressable is what got tapped five times.
                    ? const Padding(
                        padding: EdgeInsets.all(GarageTokens.space3),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        // Flush with the hint above it, not 12 px in.
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: AlignmentDirectional.centerStart,
                        ),
                        onPressed: () =>
                            loadSampleDataWithFeedback(context, ref),
                        child: Text(l10n.settingsSampleData),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the interval sheet on the garage's first vehicle.
  Future<void> _firstInterval(BuildContext context, WidgetRef ref) async {
    final vehicleId = await _which(context, ref);
    if (vehicleId == null || !context.mounted) {
      return;
    }
    await showReminderRuleSheet(context, vehicleId);
  }

  /// Opens [action] on the garage's vehicle, asking which when there is a
  /// choice: the card used to take the first by name, which with two cars
  /// was the wrong one half the time and looked like a decision.
  Future<void> _firstEntry(
    BuildContext context,
    WidgetRef ref,
    _QuickAction action,
  ) async {
    final vehicleId = await _which(context, ref);
    if (vehicleId == null || !context.mounted) {
      return;
    }
    await _runQuickAction(context, action, vehicleId);
  }

  Future<String?> _which(BuildContext context, WidgetRef ref) async {
    final vehicles = ref.read(vehiclesProvider).value ?? const [];
    return switch (vehicles) {
      [] => null,
      [final only] => only.id,
      _ => await showVehiclePicker(context, vehicles),
    };
  }
}

/// Fuelio and "any CSV" were two rows on the start card; they are one
/// question ("from where?") asked only once someone wants to import.
Future<void> _chooseImport(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.settingsImportFuelio),
            onTap: () => Navigator.of(context).pop('fuelio'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l10n.settingsImportCsv),
            onTap: () => Navigator.of(context).pop('csv'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) {
    return;
  }
  if (choice == 'fuelio') {
    await importFuelioWithFeedback(context, ref);
  } else {
    context.push('/import');
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: GarageTokens.space4,
              horizontal: GarageTokens.space2,
            ),
            child: Column(
              children: [
                Icon(icon, color: context.tokens.accent),
                const SizedBox(height: GarageTokens.space2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One way in. Every one of these does something when tapped, which is the
/// whole change: the checkbox this used to draw could only ever show an
/// unticked circle, and an empty checkbox beside a line you cannot act on
/// reads as a task the app is waiting for you to do somewhere else.
class _Step extends StatelessWidget {
  const _Step({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: context.tokens.accent),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Tells the seller their car has actually gone.
///
/// Until now nothing did. The vehicle simply stopped appearing — and not even
/// promptly, since the update that moves it belongs to the buyer's household
/// by the time it is evaluated, so the seller's device was never told
/// anything. Somebody who handed over a code had no way to know whether it had
/// been used except by counting the cars on their own list.
///
/// Dismissed per device rather than per garage: whether a notice has been read
/// is a property of the person reading it.
class _HandedOverNotices extends ConsumerWidget {
  const _HandedOverNotices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final unseen =
        ref.watch(unseenCompletedTransfersProvider).value ??
        const <VehicleTransfer>[];
    if (unseen.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (final transfer in unseen)
          Card(
            key: Key('handed-over-${transfer.id}'),
            margin: const EdgeInsets.fromLTRB(
              GarageTokens.space4,
              GarageTokens.space4,
              GarageTokens.space4,
              0,
            ),
            child: ListTile(
              leading: Icon(
                Icons.outbox_outlined,
                color: context.tokens.accent,
              ),
              title: Text(l10n.transferCompletedTitle),
              // Named when the name was captured. Transfers offered before
              // that column existed read as the generic sentence rather than
              // as a car called null.
              subtitle: Text(switch (transfer.vehicleNickname?.trim()) {
                final String name when name.isNotEmpty =>
                  l10n.transferCompletedNamed(name),
                _ => l10n.transferCompleted,
              }),
              trailing: TextButton(
                onPressed: () => markTransferSeen(ref, transfer.id),
                child: Text(l10n.transferCompletedDismiss),
              ),
            ),
          ),
      ],
    );
  }
}

/// The soonest projection for one vehicle, or null.
ReminderProjection? _nextUp(List<ReminderProjection> projections, String id) {
  ReminderProjection? soonest;
  for (final projection in projections) {
    if (projection.vehicleId != id) {
      continue;
    }
    if (soonest == null ||
        projection.projectedDueDate.isBefore(soonest.projectedDueDate)) {
      soonest = projection;
    }
  }
  return soonest;
}

/// The garage's name, and a way into it.
class _GarageRow extends StatelessWidget {
  const _GarageRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('dashboard-garage'),
      onTap: () => context.push('/household'),
      borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
      child: Row(
        mainAxisSize: GarageBreakpoints.isDesktop(context)
            ? MainAxisSize.min
            : MainAxisSize.max,
        children: [
          Icon(Icons.people_outline, size: 18, color: context.tokens.muted),
          const SizedBox(width: GarageTokens.space2),
          Flexible(
            fit: GarageBreakpoints.isDesktop(context)
                ? FlexFit.loose
                : FlexFit.tight,
            child: Text(
              name,
              style: GarageTheme.eyebrow(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: context.tokens.muted),
        ],
      ),
    );
  }
}
