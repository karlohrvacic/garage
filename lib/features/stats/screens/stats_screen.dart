import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../domain/stats/stats_math.dart';
import '../../costs/cost_category_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/stats_providers.dart';
import '../widgets/cost_charts.dart';

/// Average length of a calendar month in days; used for per-month averages
/// derived from a per-day rate.
const _daysPerMonth = 30.44;

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _vehicleId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.statsTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: GarageTokens.space4),
              child: DropdownButton<String?>(
                value: _vehicleId,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.statsAllVehicles),
                  ),
                  for (final vehicle in vehicles)
                    DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.nickname),
                    ),
                ],
                onChanged: (value) => setState(() => _vehicleId = value),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.statsTabFillUps),
              Tab(text: l10n.statsTabCosts),
              Tab(text: l10n.statsTabDistance),
            ],
          ),
        ),
        body: AdaptiveContent(
          child: AsyncValueView<StatsData>(
            value: ref.watch(statsDataProvider(_vehicleId)),
            onRetry: () => ref.invalidate(statsDataProvider(_vehicleId)),
            data: (data) => TabBarView(
              children: [
                _FillUpsTab(data: data),
                _CostsTab(data: data),
                _DistanceTab(data: data, singleVehicle: _vehicleId != null),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

UnitFormat _format(BuildContext context, WidgetRef ref) {
  return UnitFormat(
    locale: Localizations.localeOf(context).languageCode,
    preferences: ref.watch(unitPreferencesProvider),
  );
}

class _FillUpsTab extends ConsumerWidget {
  const _FillUpsTab({required this.data});

  final StatsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = _format(context, ref);
    final today = DateTime.now().toUtc();

    if (data.fuel.isEmpty) {
      return EmptyState(message: l10n.statsEmpty);
    }

    final counts = StatsMath.compare(
      items: data.fuel,
      date: (e) => e.date,
      value: (_) => 1,
      today: today,
    );
    final litres = StatsMath.compare(
      items: data.fuel,
      date: (e) => e.date,
      value: (e) => e.volumeL,
      today: today,
    );
    final volumes = data.fuel.map((e) => e.volumeL).toList()..sort();
    final totalLitres = data.fuel.fold<double>(0, (sum, e) => sum + e.volumeL);

    final totalEconomyKm = data.economy.fold<double>(
      0,
      (sum, p) => sum + p.distanceKm,
    );
    final totalEconomyL = data.economy.fold<double>(
      0,
      (sum, p) => sum + p.volumeL,
    );
    final avgEconomy = totalEconomyKm > 0
        ? totalEconomyL / totalEconomyKm * 100
        : null;
    final economies = data.economy.map((p) => p.litersPer100Km).toList()
      ..sort();

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        _BigStat(
          label: l10n.statsFillUps,
          value: '${data.fuel.length}',
          comparison: counts,
          formatValue: (v) => v.toStringAsFixed(0),
        ),
        _BigStat(
          label: l10n.statsFuelVolume,
          value: format.formatVolume(totalLitres),
          comparison: litres,
          formatValue: format.formatVolume,
        ),
        _StatCard(
          rows: [
            (l10n.statsMinFill, format.formatVolume(volumes.first)),
            (l10n.statsMaxFill, format.formatVolume(volumes.last)),
            if (avgEconomy != null)
              (l10n.statsAvgEconomy, format.formatEconomy(avgEconomy)),
            if (economies.isNotEmpty) ...[
              (l10n.statsBestEconomy, format.formatEconomy(economies.first)),
              (l10n.statsWorstEconomy, format.formatEconomy(economies.last)),
            ],
          ],
        ),
      ],
    );
  }
}

class _CostsTab extends ConsumerWidget {
  const _CostsTab({required this.data});

  final StatsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = _format(context, ref);
    final today = DateTime.now().toUtc();

    final spendItems = [
      for (final e in data.fuel)
        if (e.total != null) (date: e.date, amount: e.total!, fuel: true),
      for (final e in data.services)
        if (e.cost != null) (date: e.date, amount: e.cost!, fuel: false),
      for (final e in data.costs) (date: e.date, amount: e.amount, fuel: false),
    ];

    if (spendItems.isEmpty) {
      return EmptyState(message: l10n.statsEmpty);
    }

    final withFuel = StatsMath.compare(
      items: spendItems,
      date: (i) => i.date,
      value: (i) => i.amount,
      today: today,
    );
    final withoutFuel = StatsMath.compare(
      items: spendItems.where((i) => !i.fuel),
      date: (i) => i.date,
      value: (i) => i.amount,
      today: today,
    );
    final fuelOnly = StatsMath.compare(
      items: spendItems.where((i) => i.fuel),
      date: (i) => i.date,
      value: (i) => i.amount,
      today: today,
    );

    final total = spendItems.fold<double>(0, (sum, i) => sum + i.amount);
    final nonFuelBills =
        spendItems.where((i) => !i.fuel).map((i) => i.amount).toList()..sort();
    final unitPrices = [
      for (final e in data.fuel)
        if (e.pricePerL != null) e.pricePerL!,
    ]..sort();

    double distance = 0;
    for (final readings in data.readingsPerVehicle) {
      distance += StatsMath.distanceCovered(readings.map((r) => r.km)) ?? 0;
    }
    final days = StatsMath.spanDays(spendItems.map((i) => i.date));
    final perDay = days > 0 ? total / days : null;

    final byCategory = <String, double>{};
    for (final e in data.costs) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        _BigStat(
          label: l10n.statsTotalWithFuel,
          value: format.formatMoney(total),
          comparison: withFuel,
          formatValue: format.formatMoney,
        ),
        _BigStat(
          label: l10n.statsTotalWithoutFuel,
          value: format.formatMoney(
            spendItems
                .where((i) => !i.fuel)
                .fold<double>(0, (sum, i) => sum + i.amount),
          ),
          comparison: withoutFuel,
          formatValue: format.formatMoney,
        ),
        _BigStat(
          label: l10n.statsFuelOnly,
          value: format.formatMoney(
            spendItems
                .where((i) => i.fuel)
                .fold<double>(0, (sum, i) => sum + i.amount),
          ),
          comparison: fuelOnly,
          formatValue: format.formatMoney,
        ),
        _StatCard(
          rows: [
            if (nonFuelBills.isNotEmpty) ...[
              (l10n.statsLowestBill, format.formatMoney(nonFuelBills.first)),
              (l10n.statsHighestBill, format.formatMoney(nonFuelBills.last)),
            ],
            if (unitPrices.isNotEmpty) ...[
              (l10n.statsBestFuelPrice, format.formatMoney(unitPrices.first)),
              (l10n.statsWorstFuelPrice, format.formatMoney(unitPrices.last)),
            ],
            if (distance > 0)
              (
                l10n.statsAvgCost,
                '${format.formatMoney(total / distance)}/'
                    '${format.formatDistance(1, decimals: 0).split(' ').last}',
              ),
            if (perDay != null) ...[
              (l10n.statsAvgPerDay, format.formatMoney(perDay)),
              (
                l10n.statsAvgPerMonth,
                format.formatMoney(perDay * _daysPerMonth),
              ),
            ],
          ],
        ),
        if (byCategory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: GarageTokens.space3),
            child: Text(
              l10n.statsCategories.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
          ),
          _StatCard(
            rows: [
              for (final entry
                  in byCategory.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                (
                  costCategoryLabel(l10n, entry.key),
                  format.formatMoney(entry.value),
                ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: GarageTokens.space3),
          child: Text(
            l10n.statsCharts.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
        ),
        CostDonut(
          format: format,
          slices: [
            SpendSlice(
              key: 'fuel',
              amount: spendItems
                  .where((i) => i.fuel)
                  .fold(0, (sum, i) => sum + i.amount),
            ),
            SpendSlice(
              key: 'service',
              amount: data.services.fold(0, (sum, e) => sum + (e.cost ?? 0)),
            ),
            for (final entry
                in byCategory.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
              SpendSlice(key: entry.key, amount: entry.value),
          ],
        ),
        MonthlySpendBars(format: format, months: _lastTwelveMonths(today)),
      ],
    );
  }

  /// Fuel/other spend for the 12 calendar months ending in [today]'s month.
  List<MonthSpend> _lastTwelveMonths(DateTime today) {
    final months = <MonthSpend>[];
    for (var offset = 11; offset >= 0; offset--) {
      final month = DateTime.utc(today.year, today.month - offset);
      double fuel = 0;
      double other = 0;
      for (final e in data.fuel) {
        if (e.total != null &&
            e.date.year == month.year &&
            e.date.month == month.month) {
          fuel += e.total!;
        }
      }
      for (final e in data.services) {
        if (e.cost != null &&
            e.date.year == month.year &&
            e.date.month == month.month) {
          other += e.cost!;
        }
      }
      for (final e in data.costs) {
        if (e.date.year == month.year && e.date.month == month.month) {
          other += e.amount;
        }
      }
      months.add(MonthSpend(month: month, fuel: fuel, other: other));
    }
    return months;
  }
}

class _DistanceTab extends ConsumerWidget {
  const _DistanceTab({required this.data, required this.singleVehicle});

  final StatsData data;
  final bool singleVehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final format = _format(context, ref);
    final today = DateTime.now().toUtc();

    final allReadings = [
      for (final readings in data.readingsPerVehicle) ...readings,
    ];
    if (allReadings.isEmpty) {
      return EmptyState(message: l10n.statsEmpty);
    }

    double tracked = 0;
    for (final readings in data.readingsPerVehicle) {
      tracked += StatsMath.distanceCovered(readings.map((r) => r.km)) ?? 0;
    }

    double inPeriod(bool Function(DateTime) test) {
      double sum = 0;
      for (final readings in data.readingsPerVehicle) {
        sum +=
            StatsMath.distanceInPeriod<OdometerReading>(
              items: readings,
              date: (r) => r.date,
              odometer: (r) => r.km,
              inPeriod: test,
            ) ??
            0;
      }
      return sum;
    }

    final prevMonthAnchor = DateTime.utc(today.year, today.month - 1);
    final comparison = YearMonthComparison(
      thisYear: inPeriod((d) => d.year == today.year),
      previousYear: inPeriod((d) => d.year == today.year - 1),
      thisMonth: inPeriod(
        (d) => d.year == today.year && d.month == today.month,
      ),
      previousMonth: inPeriod(
        (d) =>
            d.year == prevMonthAnchor.year && d.month == prevMonthAnchor.month,
      ),
    );

    final days = StatsMath.spanDays(allReadings.map((r) => r.date));
    final perDay = days > 0 ? tracked / days : null;
    final lastOdometer = singleVehicle
        ? allReadings.map((r) => r.km).reduce((a, b) => a > b ? a : b)
        : null;

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        _BigStat(
          label: l10n.statsDistanceTracked,
          value: format.formatDistance(tracked, decimals: 0),
          comparison: comparison,
          formatValue: (v) => format.formatDistance(v, decimals: 0),
        ),
        _StatCard(
          rows: [
            if (lastOdometer != null)
              (
                l10n.statsLastOdometer,
                format.formatDistance(lastOdometer.toDouble(), decimals: 0),
              ),
            if (perDay != null) ...[
              (l10n.statsAvgPerDay, format.formatDistance(perDay, decimals: 0)),
              (
                l10n.statsAvgPerMonth,
                format.formatDistance(perDay * _daysPerMonth, decimals: 0),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A headline figure with its four-way year/month comparison beneath.
class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.comparison,
    required this.formatValue,
  });

  final String label;
  final String value;
  final YearMonthComparison comparison;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    Widget cell(String label, double value) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatValue(value),
              style: GarageTheme.numeric(textTheme.titleSmall!),
            ),
            Text(label, style: textTheme.labelSmall),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GarageTheme.eyebrow(context)),
            const SizedBox(height: GarageTokens.space1),
            Text(value, style: GarageTheme.numeric(textTheme.headlineSmall!)),
            const Divider(height: GarageTokens.space5),
            Row(
              children: [
                cell(l10n.statsThisYear, comparison.thisYear),
                cell(l10n.statsPreviousYear, comparison.previousYear),
              ],
            ),
            const SizedBox(height: GarageTokens.space3),
            Row(
              children: [
                cell(l10n.statsThisMonth, comparison.thisMonth),
                cell(l10n.statsPreviousMonth, comparison.previousMonth),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Label/value rows in a flat card; values in mono.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GarageTokens.space4,
          vertical: GarageTokens.space2,
        ),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: GarageTokens.space2,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: textTheme.bodyMedium)),
                    Text(
                      value,
                      style: GarageTheme.numeric(textTheme.bodyMedium!),
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
