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
import '../../../domain/maintenance/date_math.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/dashboard_providers.dart';
import '../../costs/cost_category_labels.dart';
import '../../maintenance/service_type_labels.dart' as service_labels;
import '../../timeline/providers/timeline_providers.dart';
import '../../fuel/widgets/fuel_entry_sheet.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../widgets/bundle_card.dart';
import '../widgets/household_metrics_strip.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Holds the realtime subscription open for as long as the dashboard — the
    // app's landing screen — is mounted, so a household's devices stay in sync.
    ref.watch(realtimeSyncProvider);

    final l10n = AppLocalizations.of(context)!;

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

    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    final topBundle = ref.watch(topBundleProvider).value;
    final projections =
        ref.watch(householdProjectionsProvider).value ?? const [];
    final today = DateMath.dateOnly(ref.watch(todayProvider));

    return GarageTabScaffold(
      current: GarageTab.dashboard,
      // A dashboard is the case for using the window: cards in columns, not a
      // reading column of stacked cards on a 1500px monitor.
      contentWidth: ContentWidth.wide,
      title: l10n.dashboardTitle,
      actions: [
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
              onPressed: () => _showQuickAdd(context, ref),
              child: const Icon(Icons.add),
            ),
      body: AsyncValueView<List<Vehicle>>(
        value: ref.watch(vehiclesProvider),
        onRetry: () {
          ref
            ..invalidate(currentHouseholdProvider)
            ..invalidate(allVehiclesProvider);
        },
        // A brand-new household lands here first. "Nothing here yet" told
        // them nothing about what to do next.
        empty: () => const SingleChildScrollView(
          padding: EdgeInsets.all(GarageTokens.space4),
          child: _GettingStarted(hasVehicle: false),
        ),
        data: (vehicles) {
          final vehicleNames = {for (final v in vehicles) v.id: v.nickname};
          return RefreshIndicator(
            // Family-wide invalidation: the metrics strip and due list derive
            // from per-vehicle fuel/service/rule providers, and a pull that
            // left those cached would refresh almost nothing.
            onRefresh: () async {
              ref
                ..invalidate(allVehiclesProvider)
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
              padding: const EdgeInsets.only(bottom: GarageTokens.space8),
              children: [
                // The strip spans the full width; everything below it flows
                // into two columns on a desktop window and stacks on a phone.
                const HouseholdMetricsStrip(),
                if ((ref.watch(timelineProvider).value ?? const []).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(GarageTokens.space4),
                    child: _GettingStarted(hasVehicle: true),
                  ),
                AdaptiveColumns(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GarageTokens.space4,
                      ),
                      child: topBundle == null
                          ? _NoBundles(message: l10n.dashboardNoBundles)
                          : BundleCard(
                              bundle: topBundle,
                              vehicleNames: vehicleNames,
                            ),
                    ),
                    if (projections.isNotEmpty)
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
                          for (final projection in projections.take(5))
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
                                    serviceTypeLabel(
                                      l10n,
                                      projection.serviceTypeKey,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${vehicleNames[projection.vehicleId] ?? ''} · '
                                    '${format.formatDate(projection.projectedDueDate.isBefore(today) ? today : projection.projectedDueDate)}',
                                  ),
                                  onTap: () => context.push(
                                    '/vehicles/${projection.vehicleId}/maintenance',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    if ((ref.watch(timelineProvider).value ?? const [])
                        .isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          GarageTokens.space4,
                          GarageTokens.space4,
                          GarageTokens.space4,
                          GarageTokens.space1,
                        ),
                        child: _RecentActivityCard(
                          items: ref
                              .watch(timelineProvider)
                              .value!
                              .take(4)
                              .toList(),
                          vehicleNames: vehicleNames,
                          format: format,
                        ),
                      ),
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
                                subtitle: switch (ref
                                    .watch(currentOdometerProvider(vehicle.id))
                                    .value) {
                                  null => null,
                                  final km => Text(
                                    format.formatDistance(
                                      km.toDouble(),
                                      decimals: 0,
                                    ),
                                    style: GarageTheme.numeric(
                                      Theme.of(context).textTheme.labelSmall!,
                                    ),
                                  ),
                                },
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.local_gas_station),
                                      onPressed: () => context.push(
                                        '/vehicles/${vehicle.id}/fuel',
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.build_outlined),
                                      onPressed: () => context.push(
                                        '/vehicles/${vehicle.id}/maintenance',
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () =>
                                    context.push('/vehicles/${vehicle.id}'),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                        },
                        size: 16,
                        color: context.tokens.muted,
                      ),
                      const SizedBox(width: GarageTokens.space2),
                      Expanded(
                        child: Text(
                          switch (item.kind) {
                            TimelineKind.fuel => l10n.fuelTitle,
                            TimelineKind.service =>
                              item.serviceTypeKeys
                                  .map(
                                    (key) => service_labels.serviceTypeLabel(
                                      l10n,
                                      key,
                                    ),
                                  )
                                  .join(', '),
                            TimelineKind.cost => costCategoryLabel(
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

/// Offers the three things a household records, and asks which car only when
/// there is more than one: a single-car household should never be made to
/// answer a question with one possible answer.
Future<void> _showQuickAdd(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final vehicles = await ref.read(allVehiclesProvider.future);
  if (vehicles.isEmpty || !context.mounted) {
    return;
  }

  final action = await showModalBottomSheet<_QuickAction>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.local_gas_station_outlined),
            title: Text(l10n.quickAddFuel),
            onTap: () => Navigator.of(context).pop(_QuickAction.fuel),
          ),
          ListTile(
            leading: const Icon(Icons.build_outlined),
            title: Text(l10n.quickAddService),
            onTap: () => Navigator.of(context).pop(_QuickAction.service),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(l10n.quickAddCost),
            onTap: () => Navigator.of(context).pop(_QuickAction.cost),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) {
    return;
  }

  var vehicleId = vehicles.first.id;
  if (vehicles.length > 1) {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.quickAddPickVehicle), dense: true),
            for (final vehicle in vehicles)
              ListTile(
                title: Text(vehicle.nickname),
                onTap: () => Navigator.of(context).pop(vehicle.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    vehicleId = picked;
  }

  switch (action) {
    case _QuickAction.fuel:
      await showFuelEntrySheet(context, vehicleId);
    case _QuickAction.service:
      await showServiceEntrySheet(context, vehicleId);
    case _QuickAction.cost:
      await showCostEntrySheet(context, vehicleId);
  }
}

enum _QuickAction { fuel, service, cost }

/// The three steps that are the whole app: a car, a fill-up, and what the car
/// needs next. Shown until there is history to show instead, and ticking off
/// as each is done, so a new household can see where it is rather than facing
/// an empty screen and a single button.
class _GettingStarted extends ConsumerWidget {
  const _GettingStarted({required this.hasVehicle});

  final bool hasVehicle;

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
              l10n.gettingStarted.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
            _Step(
              label: l10n.gettingStartedVehicle,
              done: hasVehicle,
              onTap: () => context.push('/vehicles/new'),
            ),
            _Step(label: l10n.gettingStartedFuel, done: false),
            _Step(label: l10n.gettingStartedReminder, done: false),
            const SizedBox(height: GarageTokens.space3),
            Text(
              hasVehicle ? l10n.gettingStartedDone : l10n.gettingStartedSample,
              style: TextStyle(color: context.tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done, this.onTap});

  final String label;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? context.tokens.accent : context.tokens.muted,
      ),
      title: Text(label),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _NoBundles extends StatelessWidget {
  const _NoBundles({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Text(message, style: TextStyle(color: context.tokens.muted)),
      ),
    );
  }
}
