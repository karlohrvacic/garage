import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/pick_one.dart';
import '../../../domain/entities/incident.dart';
import '../../company/widgets/driver_on_date.dart';
import '../../settings/providers/unit_providers.dart';
import '../incident_labels.dart';
import '../providers/incident_providers.dart';
import 'incident_sheet.dart';

/// What happened to this car and what became of it. Beside the
/// observations on the car's own tab: a problem is a state, and so is a
/// dent nobody has been to the insurer about.
class IncidentsCard extends ConsumerWidget {
  const IncidentsCard({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final read = ref.watch(incidentsProvider(vehicleId));
    final incidents = read.value;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.incidentsTitle.toUpperCase(),
                    style: GarageTheme.eyebrow(context),
                  ),
                ),
                TextButton.icon(
                  key: const Key('incident-add'),
                  onPressed: () =>
                      showIncidentSheet(context, vehicleId: vehicleId),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.incidentAdd),
                ),
              ],
            ),
            // A read that failed with nothing cached is said, and the cause
            // reaches the failure log: a header over nothing looked the same
            // whether the list was loading or refused.
            if (incidents == null && read.hasError)
              Padding(
                padding: const EdgeInsets.only(top: GarageTokens.space2),
                child: Text(
                  failureMessage(l10n, AppFailure.from(read.error!)),
                  style: TextStyle(color: context.tokens.danger),
                ),
              )
            else if (incidents == null)
              const SizedBox.shrink()
            else if (incidents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: GarageTokens.space2),
                child: Text(
                  l10n.incidentsEmpty,
                  style: TextStyle(color: context.tokens.muted),
                ),
              )
            else
              for (final incident in incidents)
                _IncidentRow(incident: incident, format: format),
          ],
        ),
      ),
    );
  }
}

class _IncidentRow extends ConsumerWidget {
  const _IncidentRow({required this.incident, required this.format});

  final Incident incident;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final colour = incident.isOpen ? tokens.warn : tokens.muted;

    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space3),
      child: Opacity(
        opacity: incident.isOpen ? 1 : 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarageTokens.space2,
                    vertical: GarageTokens.space1,
                  ),
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      GarageTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    incidentStatusLabel(l10n, incident.status),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: GarageTokens.space3),
                Expanded(
                  child: Text(
                    [
                      incidentKindLabel(l10n, incident.kind),
                      format.formatDate(incident.happenedOn),
                      if (incident.amount case final amount?)
                        format.formatMoney(amount),
                    ].join(' · '),
                    style: TextStyle(color: tokens.muted),
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('incident-menu-${incident.id}'),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: incident.isOpen ? 'close' : 'reopen',
                      child: Text(
                        incident.isOpen
                            ? l10n.incidentClose
                            : l10n.incidentReopen,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.incidentEdit),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.incidentDelete),
                    ),
                  ],
                  onSelected: (value) => _act(context, ref, value),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: GarageTokens.space1),
              child: Text(incident.description),
            ),
            DriverOnDate(
              vehicleId: incident.vehicleId,
              date: incident.happenedOn,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(incidentControllerProvider.notifier);
    var ok = true;
    switch (action) {
      case 'close':
        // How it ended is the admin's word, asked here rather than through
        // the sheet's status field, so the day is written with it and a
        // settled report never carries an open status.
        final settledAs = await showPickOne<IncidentStatus>(
          context,
          title: l10n.incidentClose,
          options: [
            for (final status in IncidentStatus.settled)
              PickOption(
                status,
                incidentStatusLabel(l10n, status),
                key: Key('incident-close-${status.key}'),
              ),
          ],
        );
        if (settledAs == null) {
          return;
        }
        ok = await controller.close(incident, status: settledAs);
      case 'reopen':
        ok = await controller.reopen(incident);
      case 'edit':
        if (context.mounted) {
          await showIncidentSheet(
            context,
            vehicleId: incident.vehicleId,
            existing: incident,
          );
        }
      case 'delete':
        if (!context.mounted) {
          return;
        }
        final confirmed = await confirmDestructive(
          context,
          title: l10n.incidentDelete,
          body: l10n.incidentDeleteConfirm,
          confirmLabel: l10n.commonDelete,
        );
        if (confirmed) {
          ok = await controller.delete(incident);
        }
    }
    // A refused write leaves the row as it was, so the row cannot say what
    // happened: a driver closing somebody else's report is told here.
    if (!ok && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              l10n,
              failureOf(ref.read(incidentControllerProvider)),
            ),
          ),
        ),
      );
    }
  }
}
