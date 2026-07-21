import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../settings/providers/unit_providers.dart';
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
        body: AsyncValueView<List<ReminderProjection>>(
          value: projections,
          onRetry: () =>
              ref.invalidate(reminderRulesProvider(widget.vehicleId)),
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

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        for (final state in order)
          if (grouped[state]!.isNotEmpty)
            for (final projection in grouped[state]!)
              Card(
                child: ListTile(
                  leading: StateChip(state: projection.state),
                  title: Text(
                    serviceTypeLabel(l10n, projection.serviceTypeKey),
                  ),
                  subtitle: Text(_dueLabel(l10n, format, projection)),
                ),
              ),
      ],
    );
  }

  String _dueLabel(
    AppLocalizations l10n,
    UnitFormat format,
    ReminderProjection projection,
  ) {
    final date = l10n.maintenanceDueOn(
      format.formatDate(projection.projectedDueDate),
    );
    if (projection.dueOdometerKm == null) {
      return date;
    }
    final odometer = l10n.maintenanceDueAt(
      format.formatDistance(projection.dueOdometerKm!.toDouble(), decimals: 0),
    );
    return '$date · $odometer';
  }
}
