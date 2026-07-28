import 'package:garage/l10n/app_localizations.dart';

import '../../domain/entities/cost_entry.dart';

/// Resolves a cost-category key to its localized label. Unknown keys fall back
/// to the raw key so nothing renders blank.
String costCategoryLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    CostCategories.registration => l10n.costCategoryRegistration,
    CostCategories.insurance => l10n.costCategoryInsurance,
    CostCategories.parking => l10n.costCategoryParking,
    CostCategories.toll => l10n.costCategoryToll,
    CostCategories.wash => l10n.costCategoryWash,
    CostCategories.fine => l10n.costCategoryFine,
    CostCategories.equipment => l10n.costCategoryEquipment,
    CostCategories.other => l10n.costCategoryOther,
    _ => key,
  };
}
