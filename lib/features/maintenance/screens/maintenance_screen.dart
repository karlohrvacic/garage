import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/maintenance/date_math.dart';
import '../../../domain/maintenance/reminder_projection.dart';
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

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final projections = ref.watch(vehicleProjectionsProvider(widget.vehicleId));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.maintenanceTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_task),
              tooltip: l10n.maintenanceLogService,
              onPressed: () => showServiceEntrySheet(context, widget.vehicleId),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.maintenanceList, icon: const Icon(Icons.list)),
              Tab(
                text: l10n.maintenanceCalendar,
                icon: const Icon(Icons.calendar_month),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showReminderRuleSheet(context, widget.vehicleId),
          icon: const Icon(Icons.add),
          label: Text(l10n.maintenanceAddRule),
        ),
        body: AdaptiveContent(
          child: AsyncValueView<List<ReminderProjection>>(
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
      ),
    );
  }
}

/// The projections grouped overdue → due → upcoming.
class MaintenanceProjectionList extends ConsumerWidget {
  const MaintenanceProjectionList({
    required this.vehicleId,
    required this.projections,
    super.key,
  });

  final String vehicleId;
  final List<ReminderProjection> projections;

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

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
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
                          if (action == 'edit') {
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
                          if (lastByKey[projection.serviceTypeKey]
                              case final ServiceEntry previous)
                            Text(
                              l10n.maintenancePreviously(
                                _previousLabel(format, previous),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (projection.fractionConsumed case final double fraction)
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
      ],
    );
  }

  String _previousLabel(UnitFormat format, ServiceEntry entry) {
    final parts = [
      format.formatShortDate(entry.date),
      if (entry.cost != null) format.formatMoney(entry.cost),
      format.formatDistance(entry.odometerKm.toDouble(), decimals: 0),
    ];
    return parts.join(' · ');
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
