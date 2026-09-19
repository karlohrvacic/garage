import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state_art.dart';
import '../../../core/widgets/month_header.dart';
import '../../../core/widgets/state_chip.dart';
import '../../../domain/company/fleet_deadlines.dart';
import '../../../domain/format/month_grouping.dart';
import '../../../domain/maintenance/reminder_projection.dart';
import '../../costs/providers/cost_providers.dart';
import '../../documents/providers/document_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/deadline_providers.dart';
import 'fleet_retry.dart';

/// One screen, every car: what must happen this month, and what comes
/// after. The month view is what an admin reviews once a month.
class DeadlinesTab extends ConsumerStatefulWidget {
  const DeadlinesTab({super.key});

  @override
  ConsumerState<DeadlinesTab> createState() => _DeadlinesTabState();
}

class _DeadlinesTabState extends ConsumerState<DeadlinesTab> {
  bool _thisMonth = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final today = ref.watch(todayProvider);
    final names = {
      for (final vehicle in ref.watch(vehiclesProvider).value ?? const [])
        vehicle.id: vehicle.nickname,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: Text(
                  l10n.companyDeadlinesThisMonth,
                  key: const Key('deadlines-this-month'),
                ),
              ),
              ButtonSegment(
                value: false,
                label: Text(
                  l10n.companyDeadlinesAll,
                  key: const Key('deadlines-all'),
                ),
              ),
            ],
            selected: {_thisMonth},
            onSelectionChanged: (selection) =>
                setState(() => _thisMonth = selection.first),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<FleetDeadline>>(
            value: ref.watch(fleetDeadlinesProvider),
            // The projection reads every entry kind for the odometer series
            // (`rawOdometerSamplesProvider`), so the five leaves are named
            // with the rules and the papers: with retry off, a first-load
            // timeout on one car's fill-ups otherwise erred on every Retry.
            onRetry: fleetRetry(ref, [
              reminderRulesProvider,
              serviceEntriesProvider,
              vehicleDocumentsProvider,
              rawFuelEntriesProvider,
              costEntriesProvider,
              odometerEntriesProvider,
              tripEntriesProvider,
              incomeEntriesProvider,
            ]),
            data: (all) {
              final shown = _thisMonth
                  ? FleetDeadlines.thisMonth(all, today)
                  : all;
              if (shown.isEmpty) {
                return Center(
                  child: EmptyState(
                    motif: EmptyStateMotif.schedule,
                    message: l10n.companyDeadlinesEmpty,
                  ),
                );
              }
              final groups = MonthGrouping.of(shown, (d) => d.dueOn);
              return ListView(
                padding: const EdgeInsets.only(bottom: GarageTokens.space6),
                children: [
                  for (final group in groups) ...[
                    MonthHeader(month: group.month, locale: locale),
                    for (final deadline in group.items)
                      ListTile(
                        // Dated, because a one-off and a recurring rule of
                        // one type are two rows for the same car.
                        key: Key(
                          'deadline-${deadline.vehicleId}-'
                          '${deadline.serviceTypeKey}-'
                          '${deadline.dueOn.toIso8601String().substring(0, 10)}',
                        ),
                        leading: StateChip(
                          state: deadline.overdue
                              ? ReminderState.overdue
                              : ReminderState.upcoming,
                        ),
                        title: Text(
                          serviceTypeLabel(l10n, deadline.serviceTypeKey),
                        ),
                        subtitle: Text(names[deadline.vehicleId] ?? ''),
                        trailing: Text(format.formatDate(deadline.dueOn)),
                        onTap: () =>
                            context.push('/vehicles/${deadline.vehicleId}'),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
