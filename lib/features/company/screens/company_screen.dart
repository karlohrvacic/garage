import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_tab_bar.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/entities/household.dart';
import '../../household/providers/household_providers.dart';
import '../providers/company_providers.dart';
import '../widgets/accountant_pack_tab.dart';
import '../widgets/company_plan_banner.dart';
import '../widgets/company_settings_tab.dart';
import '../widgets/deadlines_tab.dart';
import '../widgets/drivers_and_cars_tab.dart';
import '../widgets/incidents_tab.dart';
import '../widgets/reimbursements_tab.dart';

/// The console: who has which car, and what the company prints on its
/// paperwork. Web-first — a desk's window gets the wide column — and
/// reachable on a phone through More.
class CompanyScreen extends ConsumerWidget {
  const CompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(currentHouseholdProvider);
    // Typed in by URL on a cold start, the console is built before the
    // bootstrap has answered. Until it has, nothing is known about the
    // plan or the role, so nothing is refused: a spinner, or the failure
    // if the fetch itself failed, rather than "free plan" for a frame and
    // "only an admin" for the next. A refetch keeps the value it had.
    if (!household.hasValue) {
      return GaragePageScaffold(
        title: l10n.companyTitle,
        body: AsyncValueView<Household?>(
          value: household,
          onRetry: () => ref.invalidate(garageBootstrapProvider),
          // Never reached: this branch is built only without a value.
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }

    // The console says why it holds nothing rather than showing an empty
    // grid: a garage off the plan, or somebody who is not its admin.
    Widget refused(String reason) => GaragePageScaffold(
      title: l10n.companyTitle,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space6),
          child: Text(reason, textAlign: TextAlign.center),
        ),
      ),
    );
    final garage = household.value;
    if (garage == null || !garage.isOnCompanyPlan) {
      return refused(l10n.companyPlanFree);
    }
    if (ref.watch(myRoleProvider) != 'admin') {
      return refused(l10n.companyNotAdmin);
    }

    return DefaultTabController(
      length: 6,
      child: GaragePageScaffold(
        title: l10n.companyTitle,
        contentWidth: ContentWidth.wide,
        bottom: GarageTabBar(
          labels: [
            l10n.companyTabDrivers,
            l10n.companyTabDeadlines,
            l10n.companyTabIncidents,
            l10n.companyTabReimbursements,
            l10n.companyTabPack,
            l10n.companyTabSettings,
          ],
        ),
        body: Column(
          children: [
            const CompanyPlanBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  const DriversAndCarsTab(),
                  const DeadlinesTab(),
                  const IncidentsTab(),
                  const ReimbursementsTab(),
                  const AccountantPackTab(),
                  // Keyed by the garage: its fields are seeded once, when
                  // the tab is built, and switching garage with the console
                  // open has to seed them again from the other letterhead.
                  CompanySettingsTab(
                    key: ValueKey('company-settings-${garage.id}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
