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
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/dashboard_providers.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      bottomNavigationBar: const GarageBottomNav(current: GarageTab.dashboard),
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
                const HouseholdMetricsStrip(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GarageTokens.space4,
              ),
              child: topBundle == null
                  ? _NoBundles(message: l10n.dashboardNoBundles)
                  : BundleCard(bundle: topBundle, vehicleNames: vehicleNames),
            ),
            if (projections.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GarageTokens.space4,
                  GarageTokens.space4,
                  GarageTokens.space4,
                  GarageTokens.space2,
                ),
                child: Text(
                  l10n.dashboardDueSoonest,
                  style: Theme.of(context).textTheme.titleMedium,
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
                      title: Text(
                        serviceTypeLabel(l10n, projection.serviceTypeKey),
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
            for (final vehicle in vehicles)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarageTokens.space4,
                  vertical: GarageTokens.space1,
                ),
                child: Card(
                  child: ListTile(
                    title: Text(vehicle.nickname),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.local_gas_station),
                          onPressed: () =>
                              context.push('/vehicles/${vehicle.id}/fuel'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.build_outlined),
                          onPressed: () =>
                              context.push('/vehicles/${vehicle.id}/maintenance'),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/vehicles/${vehicle.id}'),
                  ),
                ),
              ),
              ],
            ),
          );
        },
      ),
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
        child: Text(
          message,
          style: TextStyle(color: context.tokens.muted),
        ),
      ),
    );
  }
}
