import 'package:garage/l10n/app_localizations.dart';

import '../../domain/entities/incident.dart';

String incidentKindLabel(AppLocalizations l10n, IncidentKind kind) {
  return switch (kind) {
    IncidentKind.damage => l10n.incidentKindDamage,
    IncidentKind.fault => l10n.incidentKindFault,
    IncidentKind.fine => l10n.incidentKindFine,
    IncidentKind.accident => l10n.incidentKindAccident,
  };
}

String incidentStatusLabel(AppLocalizations l10n, IncidentStatus status) {
  return switch (status) {
    IncidentStatus.open => l10n.incidentStatusOpen,
    IncidentStatus.atInsurer => l10n.incidentStatusAtInsurer,
    IncidentStatus.repaired => l10n.incidentStatusRepaired,
    IncidentStatus.paid => l10n.incidentStatusPaid,
    IncidentStatus.closed => l10n.incidentStatusClosed,
  };
}
