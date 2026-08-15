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
      body: AsyncValueView<List<Vehicle>>(
        value: ref.watch(vehiclesProvider),
        onRetry: () {
          ref
            ..invalidate(currentHouseholdProvider)
            ..invalidate(allVehiclesProvider);
        },
        // A brand-new household lands here first; without a pointer to the
        // Vehicles tab the empty dashboard is a dead end.
        empty: () => EmptyState(
          message: l10n.vehiclesEmpty,
          action: FilledButton(
            onPressed: () => context.push('/vehicles/new'),
            child: Text(l10n.vehiclesAdd),
          ),
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
                                    fraction: _dueFraction(
                                      projection.projectedDueDate,
                                      today: today,
                                    ),
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

/// Time-to-due as a gauge fraction over a 90-day horizon: a full arc is three
/// months or more away; the arc's danger takeover (last 15%) lands at roughly
/// the projector's own 14-day due window.
double _dueFraction(DateTime dueDate, {required DateTime today}) {
  final daysRemaining = DateMath.daysBetween(today, dueDate);
  if (daysRemaining <= 0) {
    return 0;
  }
  return (daysRemaining / 90).clamp(0.0, 1.0);
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
