import 'package:garage/l10n/app_localizations.dart';

import '../../domain/entities/income_entry.dart';

/// The localized name of an income category key.
///
/// An unknown key falls back to "Other" rather than showing the raw key: a row
/// written by a future version of the app, or by the public API, should read as
/// something rather than as `transport_app`.
String incomeCategoryLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    IncomeCategories.ride => l10n.incomeCategoryRide,
    IncomeCategories.transportApp => l10n.incomeCategoryTransportApp,
    IncomeCategories.freight => l10n.incomeCategoryFreight,
    IncomeCategories.refund => l10n.incomeCategoryRefund,
    IncomeCategories.vehicleSale => l10n.incomeCategoryVehicleSale,
    _ => l10n.incomeCategoryOther,
  };
}
