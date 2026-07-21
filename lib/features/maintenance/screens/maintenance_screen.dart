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
import '../widgets/reminder_rule_sheet.dart';
import '../widgets/service_entry_sheet.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final projections = ref.watch(vehicleProjectionsProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.maintenanceTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: l10n.maintenanceLogService,
            onPressed: () => showServiceEntrySheet(context, vehicleId),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showReminderRuleSheet(context, vehicleId),
        icon: const Icon(Icons.add),
        label: Text(l10n.maintenanceAddRule),
      ),
      body: AsyncValueView<List<ReminderProjection>>(
        value: projections,
        onRetry: () => ref.invalidate(reminderRulesProvider(vehicleId)),
        empty: () => EmptyState(message: l10n.maintenanceEmpty),
        data: (list) => MaintenanceProjectionList(vehicleId: vehicleId, projections: list),
      ),
    );
  }
}

/// The projections grouped overdue → due → upcoming. Extracted so the calendar
/// tab (Task 5) can share the same list rendering.
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
                  subtitle: Text(
                    _dueLabel(l10n, format, projection),
                  ),
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
    final date = l10n.maintenanceDueOn(format.formatDate(projection.projectedDueDate));
    if (projection.dueOdometerKm == null) {
      return date;
    }
    final odometer = l10n.maintenanceDueAt(
      format.formatDistance(projection.dueOdometerKm!.toDouble(), decimals: 0),
    );
    return '$date · $odometer';
  }
}
