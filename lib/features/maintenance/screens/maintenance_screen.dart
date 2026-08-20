import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../../../domain/maintenance/recurring_costs.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';
import '../widgets/maintenance_calendar.dart';
import '../widgets/reminder_rule_sheet.dart';
import '../widgets/service_entry_sheet.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

/// The two things this screen can add.
enum _AddKind { service, rule }

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// Log what was done, or set up what should happen again.
  ///
  /// Ordered with the service first: recording a visit that has already
  /// happened is the everyday act, and setting an interval is the once-per-car
  /// one.
  Future<void> _showAddMenu(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final add = await showModalBottomSheet<_AddKind>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: Text(l10n.maintenanceLogService),
              subtitle: Text(l10n.maintenanceLogServiceHint),
              onTap: () => Navigator.of(context).pop(_AddKind.service),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: Text(l10n.maintenanceAddRule),
              subtitle: Text(l10n.maintenanceAddRuleHint),
              onTap: () => Navigator.of(context).pop(_AddKind.rule),
            ),
          ],
        ),
      ),
    );
    if (add == null || !context.mounted) {
      return;
    }
    switch (add) {
      case _AddKind.service:
        await showServiceEntrySheet(context, widget.vehicleId);
      case _AddKind.rule:
        await showReminderRuleSheet(context, widget.vehicleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projections = ref.watch(vehicleProjectionsProvider(widget.vehicleId));

    return DefaultTabController(
      length: 2,
      child: GaragePageScaffold(
        title: l10n.maintenanceTitle,
        bottom: TabBar(
          tabs: [
            Tab(text: l10n.maintenanceList, icon: const Icon(Icons.list)),
            Tab(
              text: l10n.maintenanceCalendar,
              icon: const Icon(Icons.calendar_month),
            ),
          ],
        ),
        // One button, two things to add. They were split across an app-bar
        // icon and a FAB, which put "log what I just had done" and "set up
        // what should happen again" in different corners of the same screen
        // with nothing to say why. The dashboard already answers this shape
        // with a menu, and this is the same menu.
        floatingActionButton: FloatingActionButton(
          key: const Key('maintenance-add'),
          onPressed: () => _showAddMenu(context),
          child: const Icon(Icons.add),
        ),
        body: AsyncValueView<List<ReminderProjection>>(
          value: projections,
          // Projections read rules, services, fuel, and the vehicle; whichever
          // of those failed is the one holding the cached error, so retry
          // refreshes them all.
          onRetry: () {
            ref
              ..invalidate(reminderRulesProvider(widget.vehicleId))
              ..invalidate(serviceEntriesProvider(widget.vehicleId))
              ..invalidate(rawFuelEntriesProvider(widget.vehicleId))
              ..invalidate(allVehiclesProvider);
          },
          empty: () => EmptyState(message: l10n.maintenanceEmpty),
          data: (list) => TabBarView(
            children: [
              MaintenanceProjectionList(
                vehicleId: widget.vehicleId,
                projections: list,
              ),
              MaintenanceCalendar(
                projections: list,
                month: _month,
                onMonthChanged: (month) => setState(() => _month = month),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The projections grouped overdue → due → upcoming.
class MaintenanceProjectionList extends ConsumerWidget {
  const MaintenanceProjectionList({
    required this.vehicleId,
    required this.projections,
    this.footer = const [],
    super.key,
  });

  final String vehicleId;
  final List<ReminderProjection> projections;

  /// Anything to show under the last due item, inside the same scroll view.
  ///
  /// The vehicle screen's recalls card used to sit below this list in a fixed
  /// block, which took height from the very thing the tab is for. In here it
  /// scrolls with the schedule it belongs to.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    // Already sorted soonest-first by the provider; grouping by state keeps the
    // most urgent band on top without reordering within a band.
    const order = [
      ReminderState.overdue,
      ReminderState.due,
      ReminderState.upcoming,
    ];
    final grouped = {
      for (final state in order)
        state: projections.where((p) => p.state == state).toList(),
    };

    final today = DateMath.dateOnly(ref.watch(todayProvider));
    final rulesById = {
      for (final rule
          in ref.watch(reminderRulesProvider(vehicleId)).value ??
              const <ReminderRule>[])
        rule.id: rule,
    };
    final services =
        ref.watch(serviceEntriesProvider(vehicleId)).value ?? const [];
    final lastByKey = <String, ServiceEntry>{};
    for (final entry in services) {
      for (final key in entry.serviceTypeKeys) {
        final current = lastByKey[key];
        if (current == null || entry.date.isAfter(current.date)) {
          lastByKey[key] = entry;
        }
      }
    }

    // Every distance-based date below rests on this figure, and until it was
    // on screen a projection built on the assumed 30 km/day looked exactly
    // like one built on four years of real driving.
    final rate = ref.watch(drivingRateProvider(vehicleId)).value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space4,
        GarageTokens.space4,
        GarageTokens.fabClearance,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: GarageTokens.space3),
          child: Text(
            rate == null
                ? l10n.maintenanceRateAssumed(
                    format.formatDailyDistance(
                      ReminderProjector.fallbackKmPerDay,
                    ),
                  )
                : l10n.maintenanceRateMeasured(
                    format.formatDailyDistance(rate),
                  ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
          ),
        ),
        for (final state in order)
          if (grouped[state]!.isNotEmpty)
            for (final projection in grouped[state]!)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: StateChip(state: projection.state),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          final rule = rulesById[projection.ruleId];
                          if (rule == null) {
                            return;
                          }
                          if (action == 'log') {
                            // A reminder raised by a cost is settled by
                            // recording the next payment, not by logging a
                            // service: nobody performs a vignette, and asking
                            // for one is why "log service → vignette expires"
                            // read as nonsense.
                            final category = RecurringCosts.categoryFor(
                              projection.serviceTypeKey,
                            );
                            if (category != null) {
                              await showCostEntrySheet(
                                context,
                                vehicleId,
                                initialCategory: category,
                              );
                            } else {
                              await showServiceEntrySheet(
                                context,
                                vehicleId,
                                initialServiceTypeKeys: {
                                  projection.serviceTypeKey,
                                },
                              );
                            }
                            ref
                              ..invalidate(reminderRulesProvider(vehicleId))
                              ..invalidate(
                                vehicleProjectionsProvider(vehicleId),
                              );
                          } else if (action == 'edit') {
                            await showReminderRuleSheet(
                              context,
                              vehicleId,
                              existing: rule,
                            );
                          } else if (await confirmDelete(context)) {
                            await ref
                                .read(maintenanceRepositoryProvider)
                                .deleteRule(rule.id);
                            ref
                              ..invalidate(reminderRulesProvider(vehicleId))
                              ..invalidate(
                                vehicleProjectionsProvider(vehicleId),
                              );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'log',
                            child: Text(l10n.reminderLogIt),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(l10n.commonEdit),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l10n.commonDelete),
                          ),
                        ],
                      ),
                      title: Text(
                        serviceTypeLabel(l10n, projection.serviceTypeKey),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_dueLabel(l10n, format, projection, today)),
                          if (_otherDeadline(l10n, format, projection)
                              case final String other)
                            Text(
                              other,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.tokens.muted),
                            ),
                          if (lastByKey[projection.serviceTypeKey]
                              case final ServiceEntry previous)
                            Text(
                              l10n.maintenancePreviously(
                                _previousLabel(l10n, format, previous),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // dueness, not fractionConsumed: the same number the
                    // dashboard's gauge shows, and defined for a one-off with
                    // only a date, which used to show no bar at all.
                    if (projection.dueness(today) case final double fraction)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          GarageTokens.space4,
                          0,
                          GarageTokens.space4,
                          GarageTokens.space4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  GarageTokens.radiusPill,
                                ),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 5,
                                  backgroundColor: context.tokens.border,
                                  color: fraction >= 0.85
                                      ? context.tokens.danger
                                      : context.tokens.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: GarageTokens.space3),
                            Text(
                              '${(fraction * 100).round()}%',
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
        ...footer,
      ],
    );
  }

  /// The visit a due item was last settled by: when, what it cost, and at what
  /// reading.
  ///
  /// A visit that covered several items says so alongside its cost. It used to
  /// print the whole amount against every item it covered, so one 200 EUR
  /// service on four items read as "200,00 €" four times down the list.
  /// Nothing summed it, so no total was wrong — but four identical amounts
  /// invite exactly the wrong arithmetic.
  String _previousLabel(
    AppLocalizations l10n,
    UnitFormat format,
    ServiceEntry entry,
  ) {
    final cost = entry.cost;
    final covered = entry.serviceTypeKeys.length;
    final parts = [
      format.formatShortDate(entry.date),
      if (cost != null)
        if (covered > 1)
          l10n.maintenanceCostForItems(format.formatMoney(cost), covered)
        else
          format.formatMoney(cost),
      format.formatDistance(entry.odometerKm.toDouble(), decimals: 0),
    ];
    return parts.join(' · ');
  }

  /// The deadline that did *not* bind, when a rule has two and they fall on
  /// different days. Null otherwise.
  ///
  /// A rule reading "every 30,000 km or 24 months" has two deadlines, and the
  /// projection keeps only the earlier one as its date. Which one that is, and
  /// how far behind the other sits, is what a driver plans around: a car that
  /// will reach its odometer target ten months before the calendar asks is a
  /// car whose service is next autumn, not the summer after.
  ///
  /// Two deadlines on the same day are one deadline, and saying it twice is
  /// noise on a row that already carries four lines.
  static String? _otherDeadline(
    AppLocalizations l10n,
    UnitFormat format,
    ReminderProjection projection,
  ) {
    final byDistance = projection.dateFromDistance;
    final byTime = projection.dateFromTime;
    if (byDistance == null || byTime == null || byDistance == byTime) {
      return null;
    }
    return byDistance.isBefore(byTime)
        ? l10n.maintenanceOtherDeadlineByDate(format.formatDate(byTime))
        : l10n.maintenanceOtherDeadlineByDistance(
            format.formatDate(byDistance),
          );
  }

  String _dueLabel(
    AppLocalizations l10n,
    UnitFormat format,
    ReminderProjection projection,
    DateTime today,
  ) {
    // An overdue item reads as due today: the projection can extrapolate an
    // arbitrarily deep past date for something long overdue by distance, and
    // "due in 2014" helps nobody decide when to book the visit.
    final effectiveDue = projection.projectedDueDate.isBefore(today)
        ? today
        : projection.projectedDueDate;
    final date = l10n.maintenanceDueOn(format.formatDate(effectiveDue));
    if (projection.dueOdometerKm == null) {
      return date;
    }
    final odometer = l10n.maintenanceDueAt(
      format.formatDistance(projection.dueOdometerKm!.toDouble(), decimals: 0),
    );
    return '$date · $odometer';
  }
}
