import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../../domain/entities/vehicle.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/vehicle_providers.dart';
import '../widgets/economy_chart.dart';
import '../widgets/economy_gauge.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.watch(vehicleProvider(vehicleId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(vehicle.value?.nickname ?? l10n.vehiclesTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.vehicleEdit,
              onPressed: () => context.push('/vehicles/$vehicleId/edit'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                text: l10n.vehicleTabEconomy,
                icon: const Icon(Icons.speed),
              ),
              Tab(
                text: l10n.vehicleTabMaintenance,
                icon: const Icon(Icons.build_outlined),
              ),
              Tab(
                text: l10n.vehicleTabHistory,
                icon: const Icon(Icons.history),
              ),
            ],
          ),
        ),
        body: AsyncValueView<Vehicle?>(
          value: vehicle,
          onRetry: () => ref.invalidate(allVehiclesProvider),
          data: (value) {
            if (value == null) {
              return Center(child: Text(l10n.errorNotFound));
            }
            return TabBarView(
              children: [
                _EconomyTab(vehicleId: vehicleId),
                _MaintenanceTab(vehicleId: vehicleId),
                _HistoryTab(vehicleId: vehicleId),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EconomyTab extends ConsumerWidget {
  const _EconomyTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final points = ref.watch(economyPointsProvider(vehicleId));

    return AsyncValueView(
      value: points,
      onRetry: () => ref.invalidate(rawFuelEntriesProvider(vehicleId)),
      data: (list) => ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Center(
            child: EconomyGauge(
              litersPer100Km: ref.watch(averageEconomyProvider(vehicleId)).value,
              label: format.formatEconomy(
                ref.watch(averageEconomyProvider(vehicleId)).value,
              ),
            ),
          ),
          const SizedBox(height: GarageTokens.space6),
          EconomyChart(points: list),
          const SizedBox(height: GarageTokens.space4),
          OutlinedButton.icon(
            onPressed: () => context.push('/vehicles/$vehicleId/fuel'),
            icon: const Icon(Icons.local_gas_station),
            label: Text(l10n.fuelTitle),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final projections = ref.watch(vehicleProjectionsProvider(vehicleId));
    final today = DateMath.dateOnly(ref.watch(todayProvider));

    return Column(
      children: [
        Expanded(
          child: AsyncValueView(
            value: projections,
            onRetry: () {
              ref
                ..invalidate(reminderRulesProvider(vehicleId))
                ..invalidate(serviceEntriesProvider(vehicleId))
                ..invalidate(rawFuelEntriesProvider(vehicleId))
                ..invalidate(allVehiclesProvider);
            },
            empty: () => EmptyState(message: l10n.maintenanceEmpty),
            data: (list) => ListView(
              padding: const EdgeInsets.all(GarageTokens.space4),
              children: [
                for (final projection in list)
                  Card(
                    child: ListTile(
                      leading: StateChip(state: projection.state),
                      title: Text(
                        serviceTypeLabel(l10n, projection.serviceTypeKey),
                      ),
                      subtitle: Text(
                        // Overdue items read as due today; the raw projection
                        // can sit arbitrarily deep in the past.
                        l10n.maintenanceDueOn(
                          format.formatDate(
                            projection.projectedDueDate.isBefore(today)
                                ? today
                                : projection.projectedDueDate,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: OutlinedButton.icon(
            onPressed: () => context.push('/vehicles/$vehicleId/maintenance'),
            icon: const Icon(Icons.build_outlined),
            label: Text(l10n.maintenanceTitle),
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final entries = ref.watch(serviceEntriesProvider(vehicleId));

    return AsyncValueView<List<ServiceEntry>>(
      value: entries,
      onRetry: () => ref.invalidate(serviceEntriesProvider(vehicleId)),
      empty: () => EmptyState(message: l10n.vehicleNoHistoryYet),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.all(GarageTokens.space4),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: GarageTokens.space2),
        itemBuilder: (context, index) {
          final entry = list[index];
          final labels = entry.serviceTypeKeys
              .map((key) => serviceTypeLabel(l10n, key))
              .join(', ');
          return Card(
            child: ListTile(
              title: Text(labels),
              subtitle: Text(
                '${format.formatShortDate(entry.date)} · '
                '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}'
                '${entry.shop == null ? '' : ' · ${entry.shop}'}',
              ),
              trailing: entry.cost == null
                  ? null
                  : Text(
                      format.formatMoney(entry.cost),
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.labelMedium!,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
