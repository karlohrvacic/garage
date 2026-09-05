import 'package:garage/l10n/app_localizations.dart';

import '../../domain/entities/vehicle_document.dart';

/// The translated name of a document type.
///
/// A [VehicleDocument] of type [DocumentType.other] carries its own label,
/// which is what a household called it; anything else is named here.
String documentTypeLabel(AppLocalizations l10n, DocumentType type) {
  return switch (type) {
    DocumentType.registration => l10n.documentTypeRegistration,
    DocumentType.roadworthiness => l10n.documentTypeRoadworthiness,
    DocumentType.insuranceLiability => l10n.documentTypeInsuranceLiability,
    DocumentType.insuranceComprehensive =>
      l10n.documentTypeInsuranceComprehensive,
    DocumentType.greenCard => l10n.documentTypeGreenCard,
    DocumentType.other => l10n.documentTypeOther,
  };
}

/// What to call one document: the household's own words when it has them,
/// and the type's name otherwise.
String documentTitle(AppLocalizations l10n, VehicleDocument document) {
  final label = document.label?.trim();
  return label == null || label.isEmpty
      ? documentTypeLabel(l10n, document.type)
      : label;
}
