import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../providers/company_providers.dart';

/// Who had the car on the entry's date, under the date on every sheet a
/// garage on the plan opens.
///
/// `created_by` stays whoever typed the entry; the driver is resolved from
/// the assignment, in the same way the export and the reimbursements
/// resolve it. Said on the sheet so an admin filing a receipt from the
/// drawer sees the name it will be filed under, and so a day with no
/// assignment reads as exactly that rather than as somebody's.
///
/// A window outlives the membership behind it, so the log can name a user
/// the member list no longer has. That reads as a former member, never as a
/// bare colon.
class DriverOnDate extends ConsumerWidget {
  const DriverOnDate({required this.vehicleId, required this.date, super.key});

  final String vehicleId;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(companyPlanProvider)) {
      return const SizedBox.shrink();
    }
    // Nothing until the log is known: the first sheet after launch must not
    // claim nobody had the car, and neither may one whose fetch failed with
    // nothing cached. A refresh keeps the last answer on screen.
    if (!ref.watch(fleetAssignmentsProvider).hasValue) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final name = ref.watch(
      driverNameOnProvider((
        vehicleId: vehicleId,
        date: DateTime.utc(date.year, date.month, date.day),
      )),
    );
    // The policy shows a driver their own windows and nothing else, so the
    // log they hold cannot say a day was nobody's: under the previous
    // driver's fine it would, and be wrong. Their own days are still named.
    // The role in the car's garage, as the rest of the car page asks it: a
    // car opened by URL can be another garage's than the one on screen.
    if (name == null && ref.watch(isDriverForVehicleProvider(vehicleId))) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: GarageTokens.space1,
        bottom: GarageTokens.space2,
      ),
      child: Text(
        driverOnDateSentence(l10n, name),
        key: const Key('driver-on-date'),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: context.tokens.muted),
      ),
    );
  }
}

/// The three answers the log gives about a day, worded once: [name] as
/// `driverNameOnProvider` answers it, so null is nobody and an empty name is
/// a former member. The incidents list prints the same sentence inline.
String driverOnDateSentence(AppLocalizations l10n, String? name) {
  return switch (name) {
    null => l10n.companyNoDriverOnDate,
    '' => l10n.companyFormerDriverOnDate,
    _ => l10n.companyDriverOnDate(name),
  };
}
