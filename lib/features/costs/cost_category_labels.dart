import 'package:garage/l10n/app_localizations.dart';

import '../../domain/entities/cost_entry.dart';
import '../../domain/maintenance/recurring_costs.dart';

/// Resolves a cost-category key to its localized label. Unknown keys fall back
/// to the raw key so nothing renders blank.
String costCategoryLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    CostCategories.registration => l10n.costCategoryRegistration,
    CostCategories.insurance => l10n.costCategoryInsurance,
    CostCategories.insuranceComprehensive =>
      l10n.costCategoryInsuranceComprehensive,
    CostCategories.parking => l10n.costCategoryParking,
    CostCategories.toll => l10n.costCategoryToll,
    CostCategories.vignette => l10n.costCategoryVignette,
    CostCategories.wash => l10n.costCategoryWash,
    CostCategories.fine => l10n.costCategoryFine,
    CostCategories.equipment => l10n.costCategoryEquipment,
    CostCategories.other => l10n.costCategoryOther,
    _ => key,
  };
}

/// Resolves a vignette validity period to its localized label.
String vignetteValidityLabel(AppLocalizations l10n, VignetteValidity validity) {
  return switch (validity) {
    VignetteValidity.day1 => l10n.costVignetteValidityDay1,
    VignetteValidity.days7 => l10n.costVignetteValidityDays7,
    VignetteValidity.days10 => l10n.costVignetteValidityDays10,
    VignetteValidity.days30 => l10n.costVignetteValidityDays30,
    VignetteValidity.months2 => l10n.costVignetteValidityMonths2,
    VignetteValidity.days60 => l10n.costVignetteValidityDays60,
    VignetteValidity.year => l10n.costVignetteValidityYear,
  };
}

/// Resolves a vignette country to its localized name.
///
/// Localized rather than the country's own name for itself: this is a list of
/// places you are driving *to*, and picking "България" out of a menu is work a
/// Croatian or English reader should not have to do.
String vignetteCountryLabel(AppLocalizations l10n, VignetteCountry country) {
  return switch (country) {
    VignetteCountry.austria => l10n.countryAustria,
    VignetteCountry.bulgaria => l10n.countryBulgaria,
    VignetteCountry.czechia => l10n.countryCzechia,
    VignetteCountry.hungary => l10n.countryHungary,
    VignetteCountry.romania => l10n.countryRomania,
    VignetteCountry.slovakia => l10n.countrySlovakia,
    VignetteCountry.slovenia => l10n.countrySlovenia,
    VignetteCountry.switzerland => l10n.countrySwitzerland,
  };
}
