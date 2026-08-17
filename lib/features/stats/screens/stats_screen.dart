import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../domain/stats/spend_breakdown.dart';
import '../../../domain/stats/spend_rate.dart';
import '../../../domain/stats/stats_math.dart';
import '../../../domain/stats/stats_period.dart';
import '../../../domain/stats/stats_section.dart';
import '../../../domain/trips/trip_log.dart';
import '../../costs/cost_category_labels.dart';
import '../../income/income_category_labels.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/vehicle_choice.dart';
import '../providers/stats_providers.dart';
import '../providers/stats_section_providers.dart';
import '../stats_section_labels.dart';
import '../widgets/monthly_spend_bars.dart';
import '../widgets/odometer_chart.dart';
import '../widgets/spend_donut.dart';

/// Average length of a calendar month in days; used for per-month averages
/// derived from a per-day rate.
const _daysPerMonth = 30.44;

/// How many named slices a donut keeps before rolling the tail into "Others".
/// Four plus a tail is what stays readable on a phone.
const _donutSlices = 4;

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _vehicleId;
  StatsPeriod _period = StatsPeriod.allTime;
  DateRange? _customRange;

  Future<void> _pickRange(DateTime today) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1),
      initialDateRange: _customRange == null
          ? null
          : DateTimeRange(start: _customRange!.from, end: _customRange!.to),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _period = StatsPeriod.custom;
      _customRange = DateRange(from: picked.start, to: picked.end);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final chosen = chosenVehicleId(vehicles, _vehicleId);
    final today = ref.watch(todayProvider).toUtc();
    final hidden = ref.watch(hiddenStatsSectionsProvider);
    final range = _period.resolve(today, customRange: _customRange);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return DefaultTabController(
      length: 4,
      child: GaragePageScaffold(
        title: l10n.statsTitle,
        contentWidth: ContentWidth.wide,
        actions: [
          DropdownButton<String?>(
            value: chosen,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.statsAllVehicles)),
              for (final vehicle in vehicles)
                DropdownMenuItem(
                  value: vehicle.id,
                  child: Text(vehicle.nickname),
                ),
            ],
            onChanged: (value) => setState(() => _vehicleId = value),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.statsCustomise,
            onPressed: () => _showCustomiseSheet(context, ref),
          ),
          const SizedBox(width: GarageTokens.space2),
        ],
        // Charts and four-way comparisons are the case for using the window:
        // twelve monthly bars and a donut with its legend read as a cramped
        // strip in a reading column.
        bottom: TabBar(
          tabs: [
            Tab(text: l10n.statsTabFillUps),
            Tab(text: l10n.statsTabCosts),
            Tab(text: l10n.statsTabDistance),
            Tab(text: l10n.statsTabTrips),
          ],
        ),
        body: AsyncValueView<StatsData>(
          value: ref.watch(statsDataProvider(chosen)),
          onRetry: () => ref.invalidate(statsDataProvider(chosen)),
          data: (all) {
            final data = all.within(range);
            // "All time" is 1900 to 2200 so nothing is filtered out; every
            // *rate* over it has to be measured against the days the household
            // actually logged, or a total is divided by three centuries.
            final span = data.span;
            final measured = range.clampedTo(span?.$1, span?.$2);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PeriodBar(
                  period: _period,
                  range: range,
                  entryCount: data.entryCount,
                  format: format,
                  onPeriod: (period) => setState(() => _period = period),
                  onPickRange: () => _pickRange(today),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _FillUpsTab(
                        data: data,
                        all: all,
                        range: measured,
                        hidden: hidden,
                        format: format,
                        today: today,
                      ),
                      _CostsTab(
                        data: data,
                        all: all,
                        range: measured,
                        hidden: hidden,
                        format: format,
                        today: today,
                      ),
                      _DistanceTab(
                        data: data,
                        all: all,
                        range: measured,
                        hidden: hidden,
                        format: format,
                        today: today,
                        singleVehicle: chosen != null,
                      ),
                      _TripsTab(
                        data: data,
                        all: all,
                        range: measured,
                        hidden: hidden,
                        format: format,
                        today: today,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Turning a section off is a display choice, so it lives behind a sheet
/// rather than in Settings: the person who wants it is looking at the thing
/// they want gone.
Future<void> _showCustomiseSheet(BuildContext context, WidgetRef ref) {
  return showAdaptiveEntrySheet<void>(context, (context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer(
      builder: (context, ref, _) {
        final sections = ref.watch(hiddenStatsSectionsProvider.notifier);
        ref.watch(hiddenStatsSectionsProvider);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.statsCustomise,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: GarageTokens.space2),
                Text(
                  l10n.statsCustomiseHint,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
                ),
                const SizedBox(height: GarageTokens.space3),
                for (final section in StatsSection.values)
                  SwitchListTile(
                    key: Key('stats-section-${section.key}'),
                    contentPadding: EdgeInsets.zero,
                    value: sections.isVisible(section),
                    title: Text(statsSectionLabel(l10n, section)),
                    onChanged: (value) => sections.setVisible(section, value),
                  ),
                const SizedBox(height: GarageTokens.space3),
                OutlinedButton(
                  onPressed: sections.showAll,
                  child: Text(l10n.statsShowAll),
                ),
              ],
            ),
          ),
        );
      },
    );
  });
}

/// The period the whole report is taken over, and how much fell inside it.
///
/// The count is next to the period on purpose: "this month" and "no entries"
/// together explain an empty screen, where either alone looks like a bug.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.period,
    required this.range,
    required this.entryCount,
    required this.format,
    required this.onPeriod,
    required this.onPickRange,
  });

  final StatsPeriod period;
  final DateRange range;
  final int entryCount;
  final UnitFormat format;
  final ValueChanged<StatsPeriod> onPeriod;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space3,
        GarageTokens.space4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in StatsPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: GarageTokens.space2),
                    child: ChoiceChip(
                      key: Key('stats-period-${option.name}'),
                      selected: period == option,
                      label: Text(_periodLabel(l10n, option)),
                      onSelected: (_) => option == StatsPeriod.custom
                          ? onPickRange()
                          : onPeriod(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: GarageTokens.space2),
          Text(
            period == StatsPeriod.allTime
                ? l10n.statsEntryCount(entryCount)
                : '${l10n.statsEntryCount(entryCount)} · '
                      '${l10n.statsPeriodRange(format.formatShortDate(range.from), format.formatShortDate(range.to))}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
          ),
        ],
      ),
    );
  }
}

String _periodLabel(AppLocalizations l10n, StatsPeriod period) {
  return switch (period) {
    StatsPeriod.allTime => l10n.statsPeriodAllTime,
    StatsPeriod.thisYear => l10n.statsThisYear,
    StatsPeriod.previousYear => l10n.statsPreviousYear,
    StatsPeriod.thisMonth => l10n.statsThisMonth,
    StatsPeriod.previousMonth => l10n.statsPreviousMonth,
    StatsPeriod.lastTwelveMonths => l10n.statsPeriodLastTwelve,
    StatsPeriod.custom => l10n.statsPeriodCustom,
  };
}

/// Distance covered inside the report's period, summed per vehicle so a fleet
/// figure is never a span across two different odometers.
double _distanceIn(StatsData data) {
  var distance = 0.0;
  for (final readings in data.readingsPerVehicle) {
    distance += StatsMath.distanceCovered(readings.map((r) => r.km)) ?? 0;
  }
  return distance;
}

/// Renders the sections the reader has left switched on, or says why the
/// screen is empty when they have turned everything off.
class _Sections extends StatelessWidget {
  const _Sections({required this.hidden, required this.children});

  final Set<StatsSection> hidden;
  final List<(StatsSection, Widget)> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = [
      for (final entry in children)
        if (!hidden.contains(entry.$1)) entry.$2,
    ];
    if (visible.isEmpty) {
      return EmptyState(message: l10n.statsNothingShown);
    }
    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [AdaptiveColumns(children: visible)],
    );
  }
}

class _FillUpsTab extends StatelessWidget {
  const _FillUpsTab({
    required this.data,
    required this.all,
    required this.range,
    required this.hidden,
    required this.format,
    required this.today,
  });

  final StatsData data;
  final StatsData all;
  final DateRange range;
  final Set<StatsSection> hidden;
  final UnitFormat format;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (data.fuel.isEmpty) {
      return EmptyState(message: l10n.statsEmpty);
    }

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

    return _Sections(
      hidden: hidden,
      children: [
        (
          StatsSection.summary,
          _SummaryCard(
            key: const Key('stats-fill-ups'),
            label: l10n.statsFillUps,
            headline: '${data.fuel.length}',
            // A count has no useful rate: "0.08 fill-ups a day" and "0.002 a
            // kilometre" are both true and neither is worth reading. The card
            // shows the number alone.
            rate: SpendRate(
              total: data.fuel.length.toDouble(),
              days: 0,
              distanceKm: 0,
            ),
            format: format,
            formatValue: (v) => v.toStringAsFixed(2),
          ),
        ),
        (
          StatsSection.summary,
          _SummaryCard(
            key: const Key('stats-fuel-volume'),
            label: l10n.statsFuelVolume,
            headline: format.formatVolume(totalLitres),
            // Per day only. Litres per kilometre *is* consumption, but written
            // as 0.06 rather than the 6.0 l/100km the rest of the app says,
            // which reads as a different and smaller number for the same fact.
            rate: SpendRate(
              total: totalLitres,
              days: range.days,
              distanceKm: 0,
            ),
            format: format,
            formatValue: format.formatVolume,
          ),
        ),
        (
          StatsSection.comparison,
          _ComparisonCard(
            label: l10n.statsFuelVolume,
            comparison: StatsMath.compare(
              items: all.fuel,
              date: (e) => e.date,
              value: (e) => e.volumeL,
              today: today,
            ),
            formatValue: format.formatVolume,
          ),
        ),
        (
          StatsSection.records,
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
        ),
        (
          StatsSection.spendByStation,
          SpendDonut(
            title: l10n.statsByStation,
            slices: SpendBreakdown.topN(
              SpendBreakdown.group([
                for (final entry in data.fuel)
                  if (entry.total != null) (entry.station, entry.total!),
              ]),
              _donutSlices,
            ),
            format: format,
          ),
        ),
      ],
    );
  }
}

class _CostsTab extends StatelessWidget {
  const _CostsTab({
    required this.data,
    required this.all,
    required this.range,
    required this.hidden,
    required this.format,
    required this.today,
  });

  final StatsData data;
  final StatsData all;
  final DateRange range;
  final Set<StatsSection> hidden;
  final UnitFormat format;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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

    final distance = _distanceIn(data);
    final total = spendItems.fold<double>(0, (sum, i) => sum + i.amount);
    final income = data.income.fold<double>(0, (sum, e) => sum + e.amount);
    final fuelTotal = spendItems
        .where((i) => i.fuel)
        .fold<double>(0, (sum, i) => sum + i.amount);
    final nonFuelBills =
        spendItems.where((i) => !i.fuel).map((i) => i.amount).toList()..sort();
    final unitPrices = [
      for (final e in data.fuel)
        if (e.pricePerL != null) e.pricePerL!,
    ]..sort();

    SpendRate rate(double amount) =>
        SpendRate(total: amount, days: range.days, distanceKm: distance);

    final byCategory = SpendBreakdown.group([
      for (final e in data.costs)
        (costCategoryLabel(l10n, e.category), e.amount),
    ]);

    final perDay = rate(total).perDay;

    return _Sections(
      hidden: hidden,
      children: [
        (
          StatsSection.summary,
          _SummaryCard(
            key: const Key('stats-total-with-fuel'),
            label: l10n.statsTotalWithFuel,
            headline: format.formatMoney(total),
            rate: rate(total),
            format: format,
            formatValue: (v) => format.formatMoney(v, decimals: 3),
          ),
        ),
        (
          StatsSection.summary,
          _SummaryCard(
            label: l10n.statsTotalWithoutFuel,
            headline: format.formatMoney(total - fuelTotal),
            rate: rate(total - fuelTotal),
            format: format,
            formatValue: (v) => format.formatMoney(v, decimals: 3),
          ),
        ),
        (
          StatsSection.summary,
          _SummaryCard(
            label: l10n.statsFuelOnly,
            headline: format.formatMoney(fuelTotal),
            rate: rate(fuelTotal),
            format: format,
            formatValue: (v) => format.formatMoney(v, decimals: 3),
          ),
        ),
        (
          StatsSection.comparison,
          _ComparisonCard(
            label: l10n.statsTotalWithFuel,
            comparison: StatsMath.compare(
              items: [
                for (final e in all.fuel)
                  if (e.total != null) (date: e.date, amount: e.total!),
                for (final e in all.services)
                  if (e.cost != null) (date: e.date, amount: e.cost!),
                for (final e in all.costs) (date: e.date, amount: e.amount),
              ],
              date: (i) => i.date,
              value: (i) => i.amount,
              today: today,
            ),
            formatValue: format.formatMoney,
          ),
        ),
        (
          StatsSection.records,
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
              if (perDay != null) ...[
                (l10n.statsAvgPerDay, format.formatMoney(perDay)),
                (
                  l10n.statsAvgPerMonth,
                  format.formatMoney(perDay * _daysPerMonth),
                ),
              ],
            ],
          ),
        ),
        if (byCategory.isNotEmpty)
          (
            StatsSection.categories,
            _LabelledSection(
              key: const Key('stats-categories'),
              title: l10n.statsCategories,
              child: _StatCard(
                rows: [
                  for (final slice in byCategory)
                    (
                      slice.label ?? l10n.statsUnlabelled,
                      format.formatMoney(slice.amount),
                    ),
                ],
              ),
            ),
          ),
        (
          StatsSection.spendByKind,
          SpendDonut(
            title: l10n.statsByKind,
            slices: SpendBreakdown.group([
              (l10n.statsFuelOnly, fuelTotal),
              (
                l10n.maintenanceTitle,
                data.services.fold<double>(0, (sum, e) => sum + (e.cost ?? 0)),
              ),
              (
                l10n.costsTitle,
                data.costs.fold<double>(0, (sum, e) => sum + e.amount),
              ),
            ]),
            format: format,
          ),
        ),
        (
          StatsSection.spendByCategory,
          SpendDonut(
            title: l10n.statsByCategory,
            slices: SpendBreakdown.topN(byCategory, _donutSlices),
            format: format,
          ),
        ),
        (
          StatsSection.balance,
          _SummaryCard(
            key: const Key('stats-balance'),
            label: l10n.statsBalance,
            // Income minus cost, and negative for nearly everybody: a car is a
            // thing you spend on. Shown as a signed figure rather than
            // "costs minus income" so the one household that does earn from
            // its car sees the number it is looking for.
            headline: format.formatMoney(income - total),
            rate: rate(income - total),
            format: format,
            formatValue: (v) => format.formatMoney(v, decimals: 3),
          ),
        ),
        (
          StatsSection.incomeByKind,
          SpendDonut(
            title: l10n.statsIncomeByKind,
            slices: SpendBreakdown.topN(
              SpendBreakdown.group([
                for (final entry in data.income)
                  (incomeCategoryLabel(l10n, entry.category), entry.amount),
              ]),
              _donutSlices,
            ),
            format: format,
          ),
        ),
        (
          StatsSection.monthlySpend,
          MonthlySpendBars(format: format, months: _monthlySpend()),
        ),
      ],
    );
  }

  /// Fuel/other spend per month across the report's period, capped at two
  /// years of bars: beyond that the axis is unreadable and the chart stops
  /// being a chart.
  List<MonthSpend> _monthlySpend() {
    final months = <MonthSpend>[];
    final first = DateTime.utc(range.from.year, range.from.month);
    final last = DateTime.utc(range.to.year, range.to.month);
    var count = (last.year - first.year) * 12 + (last.month - first.month) + 1;
    if (count > 24) {
      count = 24;
    }
    for (var offset = count - 1; offset >= 0; offset--) {
      final month = DateTime.utc(last.year, last.month - offset);
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

class _DistanceTab extends StatelessWidget {
  const _DistanceTab({
    required this.data,
    required this.all,
    required this.range,
    required this.hidden,
    required this.format,
    required this.today,
    required this.singleVehicle,
  });

  final StatsData data;
  final StatsData all;
  final DateRange range;
  final Set<StatsSection> hidden;
  final UnitFormat format;
  final DateTime today;
  final bool singleVehicle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final allReadings = [
      for (final readings in data.readingsPerVehicle) ...readings,
    ];
    if (allReadings.isEmpty) {
      return EmptyState(message: l10n.statsEmpty);
    }

    final tracked = _distanceIn(data);
    final perDay = range.days > 0 ? tracked / range.days : null;
    final lastOdometer = singleVehicle
        ? allReadings.map((r) => r.km).reduce((a, b) => a > b ? a : b)
        : null;

    double inPeriod(bool Function(DateTime) test) {
      double sum = 0;
      for (final readings in all.readingsPerVehicle) {
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

    return _Sections(
      hidden: hidden,
      children: [
        (
          StatsSection.summary,
          _SummaryCard(
            key: const Key('stats-distance'),
            label: l10n.statsDistanceTracked,
            headline: format.formatDistance(tracked, decimals: 0),
            rate: SpendRate(
              total: tracked,
              days: range.days,
              // Distance per distance is a tautology, so this card shows only
              // the per-day rate.
              distanceKm: 0,
            ),
            format: format,
            formatValue: (v) => format.formatDistance(v, decimals: 0),
          ),
        ),
        (
          StatsSection.comparison,
          _ComparisonCard(
            label: l10n.statsDistanceTracked,
            comparison: YearMonthComparison(
              thisYear: inPeriod((d) => d.year == today.year),
              previousYear: inPeriod((d) => d.year == today.year - 1),
              thisMonth: inPeriod(
                (d) => d.year == today.year && d.month == today.month,
              ),
              previousMonth: inPeriod(
                (d) =>
                    d.year == prevMonthAnchor.year &&
                    d.month == prevMonthAnchor.month,
              ),
            ),
            formatValue: (v) => format.formatDistance(v, decimals: 0),
          ),
        ),
        (
          StatsSection.records,
          _StatCard(
            rows: [
              if (lastOdometer != null)
                (
                  l10n.statsLastOdometer,
                  format.formatDistance(lastOdometer.toDouble(), decimals: 0),
                ),
              if (perDay != null) ...[
                (
                  l10n.statsAvgPerDay,
                  format.formatDistance(perDay, decimals: 0),
                ),
                (
                  l10n.statsAvgPerMonth,
                  format.formatDistance(perDay * _daysPerMonth, decimals: 0),
                ),
              ],
            ],
          ),
        ),
        (
          StatsSection.odometerChart,
          OdometerChart(
            readingsPerVehicle: data.readingsPerVehicle,
            format: format,
          ),
        ),
      ],
    );
  }
}

/// What the log says about driving rather than about spending.
class _TripsTab extends StatelessWidget {
  const _TripsTab({
    required this.data,
    required this.all,
    required this.range,
    required this.hidden,
    required this.format,
    required this.today,
  });

  final StatsData data;
  final StatsData all;
  final DateRange range;
  final Set<StatsSection> hidden;
  final UnitFormat format;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (data.trips.isEmpty) {
      return EmptyState(message: l10n.tripsEmpty);
    }

    final summary = TripLog.summarise(data.trips);
    final speed = summary.kmPerHour;

    return _Sections(
      hidden: hidden,
      children: [
        (
          StatsSection.summary,
          _SummaryCard(
            key: const Key('stats-trip-distance'),
            label: l10n.tripTotalDistance,
            headline: format.formatDistance(summary.distanceKm, decimals: 0),
            rate: SpendRate(
              total: summary.distanceKm,
              days: range.days,
              distanceKm: 0,
            ),
            format: format,
            formatValue: (v) => format.formatDistance(v, decimals: 0),
          ),
        ),
        (
          StatsSection.comparison,
          _ComparisonCard(
            label: l10n.tripTotalDistance,
            comparison: StatsMath.compare(
              items: all.trips,
              date: (t) => t.date,
              value: (t) => t.distanceKm,
              today: today,
            ),
            formatValue: (v) => format.formatDistance(v, decimals: 0),
          ),
        ),
        (
          StatsSection.records,
          _StatCard(
            rows: [
              (l10n.tripTotalTrips, '${summary.trips}'),
              (
                l10n.statsBusinessDistance,
                format.formatDistance(summary.businessKm, decimals: 0),
              ),
              (
                l10n.statsPrivateDistance,
                format.formatDistance(summary.privateKm, decimals: 0),
              ),
              if (summary.minutes > 0)
                (
                  l10n.tripTotalTime,
                  l10n.tripHoursMinutes(
                    summary.minutes ~/ 60,
                    summary.minutes % 60,
                  ),
                ),
              if (speed != null)
                (
                  l10n.tripAverageSpeed,
                  '${format.formatDistance(speed, decimals: 0)}/h',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A headline figure with what it works out to per day and per kilometre.
///
/// The two rates are the whole point of the card. "€1,699" is not comparable
/// to anything; "€4.00 a day, €0.48 a kilometre" is comparable to another car,
/// another year, or a bus ticket.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.label,
    required this.headline,
    required this.rate,
    required this.format,
    required this.formatValue,
  });

  final String label;
  final String headline;
  final SpendRate rate;
  final UnitFormat format;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    Widget cell(String label, String value) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GarageTheme.numeric(textTheme.titleSmall!)),
            Text(label, style: textTheme.labelSmall),
          ],
        ),
      );
    }

    final perKm = rate.perKm;
    final perDay = rate.perDay;

    return Card(
      margin: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: GarageTheme.eyebrow(context)),
            const SizedBox(height: GarageTokens.space1),
            Text(
              headline,
              style: GarageTheme.numeric(textTheme.headlineSmall!),
            ),
            if (perDay != null || perKm != null) ...[
              const Divider(height: GarageTokens.space5),
              Row(
                children: [
                  if (perDay != null)
                    cell(l10n.statsPerDay, formatValue(perDay)),
                  if (perKm != null)
                    cell(l10n.statsPerDistance, formatValue(perKm)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// This year against last, this month against the one before.
///
/// Always measured over the whole log rather than the chosen period: "this
/// year against last" inside a filter that says "this month" would compare two
/// slices of one month and call them years.
class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.label,
    required this.comparison,
    required this.formatValue,
  });

  final String label;
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
            Text(
              '${label.toUpperCase()} · ${l10n.statsComparison.toUpperCase()}',
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space3),
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

/// A heading and its card as one child of the column split, so the heading
/// never lands in one column with its content in the other.
class _LabelledSection extends StatelessWidget {
  const _LabelledSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: GarageTokens.space3),
          child: Text(title.toUpperCase(), style: GarageTheme.eyebrow(context)),
        ),
        child,
      ],
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
