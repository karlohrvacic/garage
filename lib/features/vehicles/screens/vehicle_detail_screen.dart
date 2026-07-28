import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../../domain/entities/vehicle.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../costs/cost_category_labels.dart';
import '../../costs/providers/cost_providers.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../reports/report_builder.dart';
import '../../maintenance/service_type_labels.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/vehicle_providers.dart';
import '../widgets/economy_chart.dart';
import '../widgets/economy_gauge.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  Future<void> _createReport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final kind = await showDialog<ReportKind>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.reportsTitle),
        children: [
          for (final (option, label) in [
            (ReportKind.sellers, l10n.reportSellers),
            (ReportKind.maintenanceHistory, l10n.reportMaintenance),
            (ReportKind.annualSummary, l10n.reportAnnual),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text(label),
            ),
        ],
      ),
    );
    if (kind == null || !context.mounted) {
      return;
    }

    final vehicle = await ref.read(vehicleProvider(vehicleId).future);
    if (vehicle == null || !context.mounted) {
      return;
    }
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.read(unitPreferencesProvider),
    );
    final data = ReportData(
      vehicle: vehicle,
      currentOdometerKm: await ref.read(
        currentOdometerProvider(vehicleId).future,
      ),
      fuel: await ref.read(rawFuelEntriesProvider(vehicleId).future),
      services: await ref.read(serviceEntriesProvider(vehicleId).future),
      costs: await ref.read(costEntriesProvider(vehicleId).future),
      economy: await ref.read(economyPointsProvider(vehicleId).future),
    );
    if (!context.mounted) {
      return;
    }
    final bytes = await buildReport(
      kind: kind,
      data: data,
      l10n: l10n,
      format: format,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(bytes),
            name: 'garage-report.pdf',
            mimeType: 'application/pdf',
          ),
        ],
        subject: l10n.reportsTitle,
      ),
    );
  }

  Future<void> _updateOdometer(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.read(vehicleProvider(vehicleId)).value;
    final current = ref.read(currentOdometerProvider(vehicleId)).value;
    if (vehicle == null) {
      return;
    }
    final controller = TextEditingController(text: current?.toString() ?? '');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.vehicleUpdateOdometer),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: GarageTheme.numericField(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (value == null || value <= (current ?? 0)) {
      return;
    }
    await ref
        .read(vehicleRepositoryProvider)
        .update(vehicle.copyWith(baselineOdometerKm: value));
    ref.invalidate(allVehiclesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.watch(vehicleProvider(vehicleId));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(vehicle.value?.nickname ?? l10n.vehiclesTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: l10n.reportsTitle,
              onPressed: () => _createReport(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.speed_outlined),
              tooltip: l10n.vehicleUpdateOdometer,
              onPressed: () => _updateOdometer(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.vehicleEdit,
              onPressed: () => context.push('/vehicles/$vehicleId/edit'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.vehicleTabEconomy, icon: const Icon(Icons.speed)),
              Tab(
                text: l10n.vehicleTabMaintenance,
                icon: const Icon(Icons.build_outlined),
              ),
              Tab(
                text: l10n.vehicleTabHistory,
                icon: const Icon(Icons.history),
              ),
              Tab(
                text: l10n.costsTitle,
                icon: const Icon(Icons.receipt_long_outlined),
              ),
            ],
          ),
        ),
        body: AdaptiveContent(
          child: AsyncValueView<Vehicle?>(
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
                  _CostsTab(vehicleId: vehicleId),
                ],
              );
            },
          ),
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
            child: ClusterReadout(
              label: l10n.vehicleCurrentOdometer,
              value: switch (ref
                  .watch(currentOdometerProvider(vehicleId))
                  .value) {
                null => UnitFormat.emptyValue,
                final km => format.formatDistance(km.toDouble(), decimals: 0),
              },
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          Center(
            child: EconomyGauge(
              litersPer100Km: ref
                  .watch(averageEconomyProvider(vehicleId))
                  .value,
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
          return Dismissible(
            key: ValueKey(entry.id),
            direction: DismissDirection.endToStart,
            background: const DeleteSwipeBackground(),
            confirmDismiss: (_) => confirmDelete(context),
            onDismissed: (_) async {
              await ref
                  .read(maintenanceRepositoryProvider)
                  .deleteServiceEntry(entry.id);
              ref
                ..invalidate(serviceEntriesProvider(vehicleId))
                ..invalidate(vehicleProjectionsProvider(vehicleId));
            },
            child: Card(
              child: ListTile(
                onTap: () =>
                    showServiceEntrySheet(context, vehicleId, existing: entry),
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
            ),
          );
        },
      ),
    );
  }
}

class _CostsTab extends ConsumerWidget {
  const _CostsTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final entries = ref.watch(costEntriesProvider(vehicleId));

    return Column(
      children: [
        Expanded(
          child: AsyncValueView(
            value: entries,
            onRetry: () => ref.invalidate(costEntriesProvider(vehicleId)),
            empty: () => EmptyState(message: l10n.costsEmpty),
            data: (list) => ListView.separated(
              padding: const EdgeInsets.all(GarageTokens.space4),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: GarageTokens.space2),
              itemBuilder: (context, index) {
                final entry = list[index];
                return Dismissible(
                  key: ValueKey(entry.id),
                  direction: DismissDirection.endToStart,
                  background: const DeleteSwipeBackground(),
                  confirmDismiss: (_) => confirmDelete(context),
                  onDismissed: (_) async {
                    await ref.read(costRepositoryProvider).delete(entry.id);
                    ref.invalidate(costEntriesProvider(vehicleId));
                  },
                  child: Card(
                    child: ListTile(
                      onTap: () => showCostEntrySheet(
                        context,
                        vehicleId,
                        existing: entry,
                      ),
                      title: Text(costCategoryLabel(l10n, entry.category)),
                      subtitle: Text(
                        '${format.formatShortDate(entry.date)}'
                        '${entry.notes == null ? '' : ' \u00b7 ${entry.notes}'}',
                      ),
                      trailing: Text(
                        format.formatMoney(entry.amount),
                        style: GarageTheme.numeric(
                          Theme.of(context).textTheme.labelMedium!,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: FilledButton.icon(
            onPressed: () => showCostEntrySheet(context, vehicleId),
            icon: const Icon(Icons.add),
            label: Text(l10n.costAdd),
          ),
        ),
      ],
    );
  }
}
