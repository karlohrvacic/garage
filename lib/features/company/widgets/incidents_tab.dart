import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../domain/entities/incident.dart';
import '../../incidents/incident_labels.dart';
import '../../incidents/providers/incident_providers.dart';
import '../../incidents/widgets/incident_sheet.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/company_providers.dart';
import 'driver_on_date.dart';

/// Every car's incidents in one place, the driver of the day beside each,
/// which is what makes a repeat offender visible.
class IncidentsTab extends ConsumerStatefulWidget {
  const IncidentsTab({super.key});

  @override
  ConsumerState<IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends ConsumerState<IncidentsTab> {
  bool _openOnly = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    // Every car the list reads, the sold ones too, so a report on one of
    // them names the car rather than printing a bare kind.
    final names = {
      for (final vehicle in ref.watch(allVehiclesProvider).value ?? const [])
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
                  l10n.incidentStatusOpen,
                  key: const Key('incidents-open'),
                ),
              ),
              ButtonSegment(
                value: false,
                label: Text(
                  l10n.incidentsFilterAll,
                  key: const Key('incidents-all'),
                ),
              ),
            ],
            selected: {_openOnly},
            onSelectionChanged: (selection) =>
                setState(() => _openOnly = selection.first),
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Incident>>(
            value: ref.watch(fleetIncidentsProvider),
            // The list derives from every car's own read; invalidating the
            // aggregate alone would re-await whichever leaf still caches
            // the error.
            onRetry: () => ref
              ..invalidate(incidentsProvider)
              ..invalidate(fleetIncidentsProvider),
            data: (all) {
              final shown = _openOnly
                  ? [
                      for (final it in all)
                        if (it.isOpen) it,
                    ]
                  : all;
              if (shown.isEmpty) {
                // "Nothing reported" only when nothing was: a fleet whose
                // reports are all settled is told so.
                return Center(
                  child: EmptyState(
                    message: all.isEmpty
                        ? l10n.incidentsEmpty
                        : l10n.incidentsNoneOpen,
                  ),
                );
              }
              // Nothing about the driver until the log is known: "no
              // driver" is a claim about the log, and the first list after
              // launch, or one whose fetch failed, must not make it.
              final logKnown = ref.watch(fleetAssignmentsProvider).hasValue;
              return ListView(
                padding: const EdgeInsets.only(bottom: GarageTokens.space6),
                children: [
                  for (final incident in shown)
                    ListTile(
                      key: Key('incident-row-${incident.id}'),
                      title: Text(
                        '${names[incident.vehicleId] ?? ''} · '
                        '${incidentKindLabel(l10n, incident.kind)}',
                      ),
                      subtitle: Text(
                        [
                          format.formatDate(incident.happenedOn),
                          incidentStatusLabel(l10n, incident.status),
                          if (logKnown)
                            driverOnDateSentence(
                              l10n,
                              ref.watch(
                                driverNameOnProvider((
                                  vehicleId: incident.vehicleId,
                                  date: incident.happenedOn,
                                )),
                              ),
                            ),
                          incident.description,
                        ].join(' · '),
                      ),
                      trailing: incident.amount == null
                          ? null
                          : Text(format.formatMoney(incident.amount)),
                      onTap: () => showIncidentSheet(
                        context,
                        vehicleId: incident.vehicleId,
                        existing: incident,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
