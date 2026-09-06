import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/format/unit_format.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../../domain/entities/trip_route.dart';
import '../../../domain/trips/route_trend.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/route_providers.dart';
import '../widgets/route_trend_chart.dart';

/// What a journey you make often actually takes, and whether that has moved.
///
/// The screen reports durations and refuses to explain them: a change of
/// departure time, road or driver looks exactly like traffic from inside the
/// records, so the filters exist to let somebody rule those out themselves.
class RouteTrendsScreen extends ConsumerStatefulWidget {
  const RouteTrendsScreen({super.key});

  @override
  ConsumerState<RouteTrendsScreen> createState() => _RouteTrendsScreenState();
}

class _RouteTrendsScreenState extends ConsumerState<RouteTrendsScreen> {
  String? _routeId;
  RouteGrouping _grouping = RouteGrouping.quarter;
  bool _weekdaysOnly = false;
  DepartureWindow _departure = DepartureWindow.any;
  String? _driver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final routes = ref.watch(routesProvider);

    return GaragePageScaffold(
      title: l10n.routeTrendsTitle,
      body: AsyncValueView<List<TripRoute>>(
        value: routes,
        onRetry: () => ref.invalidate(routesProvider),
        empty: () => EmptyState(message: l10n.routeTrendsEmpty),
        data: (routes) {
          final chosen = _chosen(routes);
          return ListView(
            padding: const EdgeInsets.all(GarageTokens.space4),
            children: [
              Text(
                l10n.routeTrendsSubtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space4),
              _RoutePicker(
                routes: routes,
                chosen: chosen,
                onChanged: (route) => setState(() {
                  _routeId = route.id;
                  // Filters belong to a route, not to the screen: "Ana" on the
                  // school run is not a filter that means anything on the
                  // commute, and carrying it over would silently empty it.
                  _driver = null;
                }),
                onRename: () => _rename(chosen),
                onDelete: () => _delete(chosen),
              ),
              const SizedBox(height: GarageTokens.space4),
              _Filters(
                routeId: chosen.id,
                grouping: _grouping,
                weekdaysOnly: _weekdaysOnly,
                departure: _departure,
                driver: _driver,
                onGrouping: (value) => setState(() => _grouping = value),
                onWeekdays: (value) => setState(() => _weekdaysOnly = value),
                onDeparture: (value) => setState(() => _departure = value),
                onDriver: (value) => setState(() => _driver = value),
              ),
              const SizedBox(height: GarageTokens.space4),
              _Trend(
                query: RouteTrendQuery(
                  routeId: chosen.id,
                  grouping: _grouping,
                  weekdaysOnly: _weekdaysOnly,
                  departure: _departure,
                  driver: _driver,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The route on screen. Falls back to the first rather than to nothing: a
  /// picker whose value has been deleted underneath it would otherwise throw.
  TripRoute _chosen(List<TripRoute> routes) {
    for (final route in routes) {
      if (route.id == _routeId) {
        return route;
      }
    }
    return routes.first;
  }

  Future<void> _rename(TripRoute route) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: route.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.routeRename),
        content: TextField(
          key: const Key('route-rename-field'),
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == route.name || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(routeControllerProvider.notifier)
        .rename(route, name);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  Future<void> _delete(TripRoute route) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.routeDelete,
      body: l10n.routeDeleteConfirm,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed) {
      return;
    }
    final ok = await ref.read(routeControllerProvider.notifier).delete(route);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      return;
    }
    if (mounted) {
      setState(() => _routeId = null);
    }
  }
}

class _RoutePicker extends StatelessWidget {
  const _RoutePicker({
    required this.routes,
    required this.chosen,
    required this.onChanged,
    required this.onRename,
    required this.onDelete,
  });

  final List<TripRoute> routes;
  final TripRoute chosen;
  final ValueChanged<TripRoute> onChanged;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: const Key('route-trend-route'),
            // Or a long route name at a large font size pushes the arrow off
            // the right of a 320 px phone. Ellipsised is legible; overflowing
            // is not.
            isExpanded: true,
            initialValue: chosen.id,
            items: [
              for (final route in routes)
                DropdownMenuItem(value: route.id, child: Text(route.name)),
            ],
            onChanged: (value) {
              for (final route in routes) {
                if (route.id == value) {
                  onChanged(route);
                  return;
                }
              }
            },
          ),
        ),
        PopupMenuButton<void Function()>(
          key: const Key('route-trend-menu'),
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            PopupMenuItem(value: onRename, child: Text(l10n.routeRename)),
            PopupMenuItem(value: onDelete, child: Text(l10n.routeDelete)),
          ],
        ),
      ],
    );
  }
}

/// How wide a filter dropdown may get. Wide enough for the longest Croatian
/// label at an ordinary font size, narrow enough that two fit beside each
/// other on a phone.
const double _filterWidth = 200;

class _Filters extends ConsumerWidget {
  const _Filters({
    required this.routeId,
    required this.grouping,
    required this.weekdaysOnly,
    required this.departure,
    required this.driver,
    required this.onGrouping,
    required this.onWeekdays,
    required this.onDeparture,
    required this.onDriver,
  });

  final String routeId;
  final RouteGrouping grouping;
  final bool weekdaysOnly;
  final DepartureWindow departure;
  final String? driver;
  final ValueChanged<RouteGrouping> onGrouping;
  final ValueChanged<bool> onWeekdays;
  final ValueChanged<DepartureWindow> onDeparture;
  final ValueChanged<String?> onDriver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final drivers = switch (ref.watch(routeDriversProvider(routeId))) {
      AsyncData(:final value) => value,
      _ => const <String>[],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<RouteGrouping>(
          key: const Key('route-trend-grouping'),
          segments: [
            ButtonSegment(
              value: RouteGrouping.month,
              label: Text(l10n.routeTrendGroupMonth),
            ),
            ButtonSegment(
              value: RouteGrouping.quarter,
              label: Text(l10n.routeTrendGroupQuarter),
            ),
          ],
          selected: {grouping},
          onSelectionChanged: (value) => onGrouping(value.first),
        ),
        const SizedBox(height: GarageTokens.space3),
        Wrap(
          spacing: GarageTokens.space3,
          runSpacing: GarageTokens.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              key: const Key('route-trend-weekdays'),
              label: Text(l10n.routeTrendWeekdays),
              selected: weekdaysOnly,
              onSelected: onWeekdays,
            ),
            // Both dropdowns are capped and expanded for the same reason as
            // the route picker above: "Sredinom dana" at 1.5x on a narrow
            // phone is wider than the space a Wrap can give it.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _filterWidth),
              child: DropdownButton<DepartureWindow>(
                key: const Key('route-trend-departure'),
                value: departure,
                isExpanded: true,
                items: [
                  for (final window in DepartureWindow.values)
                    DropdownMenuItem(
                      value: window,
                      child: Text(
                        _departureLabel(l10n, window),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => onDeparture(value ?? DepartureWindow.any),
              ),
            ),
            // Only when there is somebody to choose between. One driver's own
            // commute does not need a driver filter.
            if (drivers.length > 1)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _filterWidth),
                child: DropdownButton<String?>(
                  key: const Key('route-trend-driver'),
                  value: driver,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      child: Text(
                        l10n.routeTrendDriverAnyone,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final name in drivers)
                      DropdownMenuItem(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: onDriver,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _departureLabel(AppLocalizations l10n, DepartureWindow window) {
  return switch (window) {
    DepartureWindow.any => l10n.routeTrendDepartureAny,
    DepartureWindow.morning => l10n.routeTrendDepartureMorning,
    DepartureWindow.midday => l10n.routeTrendDepartureMidday,
    DepartureWindow.evening => l10n.routeTrendDepartureEvening,
  };
}

class _Trend extends ConsumerWidget {
  const _Trend({required this.query});

  final RouteTrendQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return AsyncValueView<RouteTrend>(
      value: ref.watch(routeTrendProvider(query)),
      onRetry: () => ref.invalidate(routeTripsProvider(query.routeId)),
      data: (trend) {
        if (trend.sampleCount == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: GarageTokens.space6),
            child: Text(
              l10n.routeTrendNoTimed,
              key: const Key('route-trend-nothing'),
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.routeTrendTypical(_minutes(l10n, trend.overallMedian!)),
              key: const Key('route-trend-typical'),
              style: GarageTheme.numeric(
                theme.textTheme.headlineSmall!,
              ).copyWith(color: tokens.fg),
            ),
            // Nothing to spread over one journey, and "middle half 1–1 min"
            // reads as a bug rather than as a sample of one.
            if (trend.overallHigh! - trend.overallLow! >= 1)
              Text(
                l10n.routeTrendSpread(
                  trend.overallLow!.round().toString(),
                  trend.overallHigh!.round().toString(),
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.routeTrendSample(trend.sampleCount),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
            if (_change(l10n, trend) case final change?) ...[
              const SizedBox(height: GarageTokens.space3),
              Text(
                change,
                key: const Key('route-trend-change'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.accent,
                ),
              ),
            ],
            if (trend.restsOnSparseData) ...[
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.routeTrendSparse,
                key: const Key('route-trend-sparse'),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.warn),
              ),
            ],
            const SizedBox(height: GarageTokens.space4),
            RouteTrendChart(buckets: trend.buckets),
            const SizedBox(height: GarageTokens.space4),
            if (trend.excluded.isNotEmpty) _Excluded(runs: trend.excluded),
            if (trend.droppedForNoStartTime > 0)
              Text(
                l10n.routeTrendNoStartTime(trend.droppedForNoStartTime),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            const SizedBox(height: GarageTokens.space3),
            Text(
              l10n.routeTrendCaveat,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ],
        );
      },
    );
  }
}

/// The change between the first and last period on screen, in the direction a
/// driver thinks in: slower or faster, against the period it is compared with.
String? _change(AppLocalizations l10n, RouteTrend trend) {
  final change = trend.changeInMinutes;
  if (change == null) {
    return null;
  }
  final label = trend.buckets.first.label;
  final rounded = change.round();
  if (rounded == 0) {
    return l10n.routeTrendUnchanged(label);
  }
  return rounded > 0
      ? l10n.routeTrendSlower(rounded.toString(), label)
      : l10n.routeTrendFaster((-rounded).toString(), label);
}

String _minutes(AppLocalizations l10n, double minutes) {
  final whole = minutes.round();
  if (whole < 60) {
    return '$whole min';
  }
  return l10n.tripHoursMinutes(whole ~/ 60, whole % 60);
}

/// The journeys somebody marked as not normal runs, named.
///
/// The count alone invites the question which ones, and leaving that
/// unanswered makes the exclusion a place data quietly goes. Listed rather
/// than drawn on the chart: they are deliberately not on its axis, and a
/// hollow dot among the boxes would put them there.
class _Excluded extends ConsumerWidget {
  const _Excluded({required this.runs});

  /// Beyond this the list stops being read and starts being scrolled past.
  static const int _shown = 5;

  final List<TripEntry> runs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: tokens.muted);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final sorted = [...runs]..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      key: const Key('route-trend-excluded-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.routeTrendExcluded(runs.length), style: style),
        for (final run in sorted.take(_shown))
          Text(
            l10n.routeTrendExcludedRun(
              format.formatShortDate(run.date),
              (run.minutes ?? 0).toString(),
            ),
            style: style,
          ),
        if (sorted.length > _shown)
          Text(
            l10n.routeTrendExcludedMore(sorted.length - _shown),
            style: style,
          ),
      ],
    );
  }
}
