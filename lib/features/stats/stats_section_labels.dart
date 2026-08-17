import 'package:garage/l10n/app_localizations.dart';

import '../../domain/stats/stats_section.dart';

/// The name a reader sees for a section they are switching off.
///
/// Kept out of the enum because the enum is domain and knows nothing about
/// localization, and out of the screen because the customise sheet and any
/// future settings row must not drift apart on wording.
String statsSectionLabel(AppLocalizations l10n, StatsSection section) {
  return switch (section) {
    StatsSection.summary => l10n.statsSummary,
    StatsSection.comparison => l10n.statsComparison,
    StatsSection.records => l10n.statsRecords,
    StatsSection.categories => l10n.statsCategories,
    StatsSection.spendByKind => l10n.statsByKind,
    StatsSection.spendByCategory => l10n.statsByCategory,
    StatsSection.spendByStation => l10n.statsByStation,
    StatsSection.balance => l10n.statsBalance,
    StatsSection.incomeByKind => l10n.statsIncomeByKind,
    StatsSection.monthlySpend => l10n.statsMonthlySpend,
    StatsSection.odometerChart => l10n.statsOdometerChart,
  };
}
