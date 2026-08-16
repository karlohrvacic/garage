import '../../../core/widgets/dialog_actions.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../costs/providers/running_cost_providers.dart';
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
import '../data/recall_lookup.dart';
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
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
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
      child: GaragePageScaffold(
        // The car's own name, falling back while it loads. A page titled after
        // the thing it shows is the point of putting the title in the content.
        title: vehicle.value?.nickname ?? l10n.vehiclesTitle,
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
          // Four labels sharing a phone's width truncated "Maintenance", and
          // Croatian "Održavanje" with it. Scrolling lets each label be its
          // own length; a desktop window has room for all four, so it keeps
          // the evenly divided strip.
          isScrollable: !GarageBreakpoints.isWide(context),
          tabAlignment: GarageBreakpoints.isWide(context)
              ? TabAlignment.fill
              : TabAlignment.start,
          tabs: [
            Tab(text: l10n.vehicleTabEconomy, icon: const Icon(Icons.speed)),
            Tab(
              text: l10n.vehicleTabMaintenance,
              icon: const Icon(Icons.build_outlined),
            ),
            Tab(text: l10n.vehicleTabHistory, icon: const Icon(Icons.history)),
            Tab(
              text: l10n.costsTitle,
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          ],
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
                _CostsTab(vehicleId: vehicleId),
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
    final energy = ref.watch(vehicleEnergyProvider(vehicleId));
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
          // Scaled against this car's own best and worst rather than a fixed
          // 4 to 12 l/100km, which flattered a small diesel, pinned a thirsty
          // car at empty, and meant nothing for an electric one. The caption
          // says what the ring is measuring, because a proportion with no
          // stated basis is not information.
          Builder(
            builder: (context) {
              final average = ref
                  .watch(averageEconomyProvider(vehicleId))
                  .value;
              final range = EconomyRange.of(list);
              return Column(
                children: [
                  EconomyGauge(
                    litersPer100Km: average,
                    label: format.formatEconomy(average, energy),
                    best: range?.best ?? EconomyGauge.defaultBest,
                    worst: range?.worst ?? EconomyGauge.defaultWorst,
                  ),
                  const SizedBox(height: GarageTokens.space2),
                  Text(
                    range == null
                        ? l10n.economyScaleNone
                        : l10n.economyScale(
                            format.formatEconomy(range.best, energy),
                            format.formatEconomy(range.worst, energy),
                          ),
                    style: TextStyle(color: context.tokens.muted),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: GarageTokens.space6),
          _RunningCostCard(vehicleId: vehicleId, format: format),
          const SizedBox(height: GarageTokens.space6),
          EconomyChart(
            points: list,
            formatEconomy: (value) => format.formatEconomy(value, energy),
          ),
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
        _RecallsCard(vehicleId: vehicleId),
        Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/vehicles/$vehicleId/maintenance'),
                  icon: const Icon(Icons.build_outlined),
                  label: Text(l10n.maintenanceTitle),
                ),
              ),
              const SizedBox(width: GarageTokens.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/vehicles/$vehicleId/tyres'),
                  icon: const Icon(Icons.tire_repair_outlined),
                  label: Text(l10n.tyresTitle),
                ),
              ),
            ],
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
            onDismissed: (_) => deleteSwipedEntry(
              context,
              delete: () => ref
                  .read(maintenanceRepositoryProvider)
                  .deleteServiceEntry(entry.id),
              refresh: () => ref
                ..invalidate(serviceEntriesProvider(vehicleId))
                ..invalidate(vehicleProjectionsProvider(vehicleId)),
            ),
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
                  onDismissed: (_) => deleteSwipedEntry(
                    context,
                    delete: () =>
                        ref.read(costRepositoryProvider).delete(entry.id),
                    refresh: () =>
                        ref.invalidate(costEntriesProvider(vehicleId)),
                  ),
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

/// Open safety recalls for this vehicle.
///
/// The source is the US registry, so a European car may have recalls it never
/// lists and may list ones that do not apply to its build — the card says so
/// rather than presenting a match as settled fact. A lookup that fails is
/// quiet: this is a bonus on a screen about maintenance, not the screen.
class _RecallsCard extends ConsumerWidget {
  const _RecallsCard({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
    final identified =
        vehicle?.make != null &&
        vehicle?.model != null &&
        vehicle?.year != null;

    final recalls = identified
        ? ref.watch(vehicleRecallsProvider(vehicleId))
        : const AsyncValue<List<Recall>>.data([]);
    if (recalls.hasError) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GarageTokens.space4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.recallsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: GarageTokens.space1),
              if (!identified)
                Text(
                  l10n.recallsNeedsDetails,
                  style: TextStyle(color: context.tokens.muted),
                )
              else ...[
                for (final recall in recalls.value ?? const <Recall>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${recall.component} · ${recall.campaign}',
                          style: TextStyle(color: context.tokens.danger),
                        ),
                        if (recall.summary != null) Text(recall.summary!),
                        if (recall.remedy != null)
                          Text(
                            recall.remedy!,
                            style: TextStyle(color: context.tokens.muted),
                          ),
                      ],
                    ),
                  ),
                if ((recalls.value ?? const []).isEmpty)
                  Text(
                    l10n.recallsNone,
                    style: TextStyle(color: context.tokens.muted),
                  ),
                const SizedBox(height: GarageTokens.space1),
                Text(
                  l10n.recallsCaveat,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the car costs to run, with fuel and upkeep separated.
///
/// The three kinds of spending live in three tables because they answer
/// different questions; this is the one question that needs all of them at
/// once, and it is the figure a driver actually quotes about a car.
class _RunningCostCard extends ConsumerWidget {
  const _RunningCostCard({required this.vehicleId, required this.format});

  final String vehicleId;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cost = ref.watch(runningCostProvider(vehicleId)).value;
    final perKm = cost?.perKm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.runningCostTitle.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
            if (cost == null || perKm == null || !cost.hasSpending)
              Text(
                l10n.runningCostNotEnough,
                style: TextStyle(color: context.tokens.muted),
              )
            else ...[
              Text(
                format.formatMoney(perKm, decimals: 3),
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.headlineSmall!,
                ),
              ),
              Text(
                l10n.runningCostPerKm,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space2),
              // Fuel and upkeep apart, because a driver asks about them apart:
              // one is how the car is driven, the other how it is looked after.
              // Wrap, not a Row: two money figures with labels do not fit on
              // one line on a phone.
              Wrap(
                spacing: GarageTokens.space3,
                children: [
                  Text(
                    l10n.runningCostFuelShare(
                      format.formatMoney(cost.fuelPerKm, decimals: 3),
                    ),
                    style: TextStyle(color: context.tokens.muted),
                  ),
                  Text(
                    l10n.runningCostUpkeepShare(
                      format.formatMoney(cost.upkeepPerKm, decimals: 3),
                    ),
                    style: TextStyle(color: context.tokens.muted),
                  ),
                ],
              ),
              const Divider(height: GarageTokens.space6),
              _CostRow(
                label: l10n.runningCostPerMonth,
                value: format.formatMoney(cost.perMonth),
              ),
              _CostRow(
                label: l10n.runningCostPerYear,
                value: format.formatMoney(cost.perYear),
              ),
              _CostRow(
                label: l10n.runningCostTotal,
                value: format.formatMoney(cost.total),
              ),
              const Divider(height: GarageTokens.space6),
              // Where the money went, because a single total invites the
              // question and does not answer it.
              Text(
                l10n.runningCostBreakdown.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              const SizedBox(height: GarageTokens.space2),
              _CostRow(
                label: l10n.runningCostFuelTotal,
                value: format.formatMoney(cost.fuel),
              ),
              _CostRow(
                label: l10n.runningCostServiceTotal,
                value: format.formatMoney(cost.service),
              ),
              _CostRow(
                label: l10n.runningCostOtherTotal,
                value: format.formatMoney(cost.other),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GarageTokens.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded: "Since you added it", and its longer Croatian
          // counterpart, leaves no room for a currency figure beside it on a
          // phone.
          Expanded(child: Text(label)),
          const SizedBox(width: GarageTokens.space3),
          Text(
            value,
            style: GarageTheme.numeric(Theme.of(context).textTheme.bodyMedium!),
          ),
        ],
      ),
    );
  }
}
