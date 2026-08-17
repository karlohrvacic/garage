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
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../costs/providers/running_cost_providers.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/errors/app_failure.dart';
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
import '../../income/income_category_labels.dart';
import '../../income/providers/income_providers.dart';
import '../../income/widgets/income_entry_sheet.dart';
import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/income_entry.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../odometer/widgets/odometer_entry_sheet.dart';
import '../../../domain/entities/odometer_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../data/recall_lookup.dart';
import '../fuel_type_labels.dart';
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
        // Charts, an economy series and four views to compare: this is the
        // case the wider column exists for. It was the only tabbed screen
        // still taking the reading width, which capped the tab strip and the
        // charts under it at a text column on a monitor.
        contentWidth: ContentWidth.wide,
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: l10n.reportsTitle,
            onPressed: () => _createReport(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.speed_outlined),
            tooltip: l10n.odometerAdd,
            // A dated reading rather than a rewrite of the vehicle's baseline:
            // the baseline says where the car stood when it was added, and
            // overwriting it loses that. Correcting a mistyped baseline is
            // still on the edit screen, where it belongs.
            onPressed: () => showOdometerEntrySheet(context, vehicleId),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: l10n.transferTitle,
            onPressed: () => context.push('/transfer?v=$vehicleId'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.vehicleEdit,
            onPressed: () => context.push('/vehicles/$vehicleId/edit'),
          ),
          // Archiving was built and reachable from nowhere: `setArchived` had
          // no caller in any screen and `archivedVehiclesProvider` none at
          // all, so a vehicle sold or scrapped stayed in every list forever.
          // Both live here rather than beside the four icons above, which a
          // phone has no room for and which are everyday actions where these
          // two are not.
          PopupMenuButton<_VehicleAction>(
            key: const Key('vehicle-menu'),
            onSelected: (action) =>
                _runVehicleAction(context, ref, vehicleId, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: (vehicle.value?.archived ?? false)
                    ? _VehicleAction.restore
                    : _VehicleAction.archive,
                child: Text(
                  (vehicle.value?.archived ?? false)
                      ? l10n.vehicleRestore
                      : l10n.vehicleArchive,
                ),
              ),
              PopupMenuItem(
                value: _VehicleAction.delete,
                child: Text(
                  l10n.vehicleDelete,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ),
            ],
          ),
        ],
        // Labels alone, like Statistics and every other tabbed screen here.
        // The icons above them doubled the strip's height and took the room
        // that made "Maintenance" — and Croatian "Održavanje" — run out of
        // space on a phone, which is what the scrolling strip was working
        // around. Four words fit; four words under four icons did not.
        bottom: TabBar(
          tabs: [
            Tab(text: l10n.vehicleTabEconomy),
            Tab(text: l10n.vehicleTabMaintenance),
            Tab(text: l10n.vehicleTabHistory),
            Tab(text: l10n.costsTitle),
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
          // A bi-fuel car's headline average mixes two fuels and is therefore
          // neither; the split beneath it is the figure that means something.
          _EconomyByFuelCard(vehicleId: vehicleId, format: format),
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

/// Consumption per fuel, for a car that takes two. Draws nothing at all for
/// the ordinary car, where the split would be the whole log restated.
class _EconomyByFuelCard extends ConsumerWidget {
  const _EconomyByFuelCard({required this.vehicleId, required this.format});

  final String vehicleId;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final byFuel =
        ref.watch(economyByFuelProvider(vehicleId)).value ?? const {};
    if (byFuel.length < 2) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space6),
      child: Card(
        key: const Key('economy-by-fuel'),
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.statsEconomyByFuel.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              const SizedBox(height: GarageTokens.space3),
              for (final entry in byFuel.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: GarageTokens.space1,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fuelTypeLabel(l10n, entry.key) ?? entry.key,
                        ),
                      ),
                      Text(
                        format.formatEconomy(
                          FuelEconomy.average(entry.value),
                          EnergyType.forFuelKey(entry.key),
                        ),
                        style: GarageTheme.numeric(
                          Theme.of(context).textTheme.bodyMedium!,
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

/// What has happened to this car: the visits it made and the readings taken
/// between them, in one list because they are one story. A reading has no cost
/// and a service has no reading of its own to log, but both are dated points
/// on the same odometer.
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final services = ref.watch(serviceEntriesProvider(vehicleId));
    final readings = ref.watch(odometerEntriesProvider(vehicleId));

    return AsyncValueView<List<ServiceEntry>>(
      value: services,
      onRetry: () => ref
        ..invalidate(serviceEntriesProvider(vehicleId))
        ..invalidate(odometerEntriesProvider(vehicleId)),
      data: (serviceList) {
        final entries = <Object>[
          ...serviceList,
          ...readings.value ?? const <OdometerEntry>[],
        ]..sort((a, b) => _historyDate(b).compareTo(_historyDate(a)));

        if (entries.isEmpty) {
          return EmptyState(message: l10n.vehicleNoHistoryYet);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(GarageTokens.space4),
          itemCount: entries.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: GarageTokens.space2),
          itemBuilder: (context, index) => switch (entries[index]) {
            final ServiceEntry entry => _ServiceHistoryRow(
              vehicleId: vehicleId,
              entry: entry,
              format: format,
            ),
            final OdometerEntry entry => _ReadingHistoryRow(
              vehicleId: vehicleId,
              entry: entry,
              format: format,
            ),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

DateTime _historyDate(Object entry) => switch (entry) {
  final ServiceEntry entry => entry.date,
  final OdometerEntry entry => entry.date,
  _ => DateTime.utc(0),
};

class _ServiceHistoryRow extends ConsumerWidget {
  const _ServiceHistoryRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final ServiceEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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
          leading: Icon(Icons.build_outlined, color: context.tokens.muted),
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
  }
}

class _ReadingHistoryRow extends ConsumerWidget {
  const _ReadingHistoryRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final OdometerEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () => ref.read(odometerRepositoryProvider).delete(entry.id),
        refresh: () => ref
          ..invalidate(odometerEntriesProvider(vehicleId))
          ..invalidate(vehicleProjectionsProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.speed_outlined, color: context.tokens.muted),
          onTap: () =>
              showOdometerEntrySheet(context, vehicleId, existing: entry),
          title: Text(l10n.odometerTitle),
          subtitle: Text(
            '${format.formatShortDate(entry.date)}'
            '${entry.notes == null ? '' : ' · ${entry.notes}'}',
          ),
          trailing: Text(
            format.formatDistance(entry.odometerKm.toDouble(), decimals: 0),
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.labelMedium!,
            ),
          ),
        ),
      ),
    );
  }
}

/// Money in and money out for one car, in one list.
///
/// Separating them would make the reader add up two screens to answer "what
/// has this car cost me", which is the only question this tab exists for.
class _CostsTab extends ConsumerWidget {
  const _CostsTab({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final costs = ref.watch(costEntriesProvider(vehicleId));
    final income = ref.watch(incomeEntriesProvider(vehicleId));

    return Column(
      children: [
        Expanded(
          child: AsyncValueView<List<CostEntry>>(
            value: costs,
            onRetry: () => ref
              ..invalidate(costEntriesProvider(vehicleId))
              ..invalidate(incomeEntriesProvider(vehicleId)),
            data: (costList) {
              final entries = <Object>[
                ...costList,
                ...income.value ?? const <IncomeEntry>[],
              ]..sort((a, b) => _moneyDate(b).compareTo(_moneyDate(a)));

              if (entries.isEmpty) {
                return EmptyState(message: l10n.costsEmpty);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(GarageTokens.space4),
                itemCount: entries.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: GarageTokens.space2),
                itemBuilder: (context, index) => switch (entries[index]) {
                  final CostEntry entry => _CostMoneyRow(
                    vehicleId: vehicleId,
                    entry: entry,
                    format: format,
                  ),
                  final IncomeEntry entry => _IncomeMoneyRow(
                    vehicleId: vehicleId,
                    entry: entry,
                    format: format,
                  ),
                  _ => const SizedBox.shrink(),
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Row(
            spacing: GarageTokens.space3,
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showCostEntrySheet(context, vehicleId),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.costAdd),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showIncomeEntrySheet(context, vehicleId),
                  icon: const Icon(Icons.savings_outlined),
                  label: Text(l10n.incomeAdd),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

DateTime _moneyDate(Object entry) => switch (entry) {
  final CostEntry entry => entry.date,
  final IncomeEntry entry => entry.date,
  _ => DateTime.utc(0),
};

class _CostMoneyRow extends ConsumerWidget {
  const _CostMoneyRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final CostEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () => ref.read(costRepositoryProvider).delete(entry.id),
        refresh: () => ref.invalidate(costEntriesProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          onTap: () => showCostEntrySheet(context, vehicleId, existing: entry),
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
  }
}

class _IncomeMoneyRow extends ConsumerWidget {
  const _IncomeMoneyRow({
    required this.vehicleId,
    required this.entry,
    required this.format,
  });

  final String vehicleId;
  final IncomeEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: const DeleteSwipeBackground(),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => deleteSwipedEntry(
        context,
        delete: () => ref.read(incomeRepositoryProvider).delete(entry.id),
        refresh: () => ref.invalidate(incomeEntriesProvider(vehicleId)),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.savings_outlined, color: context.tokens.success),
          onTap: () =>
              showIncomeEntrySheet(context, vehicleId, existing: entry),
          title: Text(incomeCategoryLabel(l10n, entry.category)),
          subtitle: Text(
            '${format.formatShortDate(entry.date)}'
            '${entry.notes == null ? '' : ' \u00b7 ${entry.notes}'}',
          ),
          // Signed, because one column of unsigned amounts would show a refund
          // and a bill as the same thing.
          trailing: Text(
            '+${format.formatMoney(entry.amount)}',
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.labelMedium!,
            ).copyWith(color: context.tokens.success),
          ),
        ),
      ),
    );
  }
}

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

enum _VehicleAction { archive, restore, delete }

/// Archive, restore, or delete — the three ways a vehicle leaves the lists.
///
/// Archiving is offered first and delete is worded to point back at it: the
/// history is usually the reason the vehicle was in here at all, and a sale is
/// the common case, where keeping the record is what a seller wants.
Future<void> _runVehicleAction(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
  _VehicleAction action,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  if (action == _VehicleAction.delete) {
    final confirmed = await confirmDestructive(
      context,
      title: l10n.vehicleDeleteTitle,
      body: l10n.vehicleDeleteBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed) {
      return;
    }
  }

  try {
    final repository = ref.read(vehicleRepositoryProvider);
    switch (action) {
      case _VehicleAction.archive:
        await repository.setArchived(vehicleId, true);
        messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleArchived)));
      case _VehicleAction.restore:
        await repository.setArchived(vehicleId, false);
        messenger.showSnackBar(SnackBar(content: Text(l10n.vehicleRestored)));
      case _VehicleAction.delete:
        await repository.delete(vehicleId);
    }
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
    return;
  }

  ref
    ..invalidate(allVehiclesProvider)
    ..invalidate(vehiclesProvider);
  // Back to the list either way: the screen we are on is about a vehicle that
  // is now archived or gone, and leaving it up shows a stale one.
  router.go('/vehicles');
}
