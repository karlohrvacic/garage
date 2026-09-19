import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/company_providers.dart';

/// Why the console will refuse a handover: the plan ran out. Nothing else
/// changes on a lapsed garage (decision 155), and the line says so before a
/// tap finds out.
class CompanyPlanBanner extends ConsumerWidget {
  const CompanyPlanBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider).value;
    final until = household?.planUntil;
    if (household == null ||
        until == null ||
        ref.watch(companyEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    return MaterialBanner(
      key: const Key('company-plan-lapsed'),
      leading: const Icon(Icons.info_outline),
      content: Text(l10n.companyPlanLapsed(format.formatDate(until.toLocal()))),
      // Nothing to do about it from here: billing writes the plan.
      actions: const [SizedBox.shrink()],
    );
  }
}
