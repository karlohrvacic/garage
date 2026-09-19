import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/entities/vehicle_assignment.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/company_providers.dart';

/// A handover the driver has not signed off, with the one button that does.
///
/// Only for a car on the list around it: a driver's windows come back from
/// every garage they drive for, and the other company's handover belongs on
/// that garage's "My cars", where its car is.
class PendingHandoversCard extends ConsumerWidget {
  const PendingHandoversCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final read = ref.watch(pendingHandoversProvider);
    // A read that failed, said where the card would be and the cause logged,
    // the console's rule: nothing here would read as nothing to sign, which
    // is a wrong answer with no trace. Not only a first read: the role is a
    // member's until the startup fetch lands, so the first answer is the
    // empty list nobody asked the server for, and a refusal follows it with
    // that list kept as its value.
    final failure = read.hasError
        ? failureMessage(l10n, AppFailure.from(read.error!))
        : null;
    final cars = {
      for (final vehicle
          in ref.watch(vehiclesProvider).value ?? const <Vehicle>[])
        vehicle.id: vehicle,
    };
    final pending = [
      for (final assignment in read.value ?? const <VehicleAssignment>[])
        if (cars[assignment.vehicleId] case final vehicle?)
          (assignment: assignment, vehicle: vehicle),
    ];
    if (failure == null && pending.isEmpty) {
      return const SizedBox.shrink();
    }
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    return Column(
      children: [
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: GarageTokens.space2),
            child: Text(
              failure,
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        for (final (:assignment, :vehicle) in pending)
          // The same spacing as the car cards below, so the list keeps one
          // rhythm from the handover to the car it names.
          Padding(
            padding: const EdgeInsets.only(bottom: GarageTokens.space2),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(
                  l10n.companyConfirmHandoverTitle(
                    format.formatDate(assignment.fromDate),
                    vehicle.nickname,
                  ),
                ),
                trailing: FilledButton.tonal(
                  style: GarageTheme.inlineButton,
                  key: Key('confirm-handover-${assignment.id}'),
                  onPressed: () => _confirm(context, ref, assignment.id),
                  child: Text(l10n.companyConfirmHandover),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The card stays on a refusal, and says why: the sign-off is the sign
  /// the paper putni blok had, and one that silently did not land is the
  /// one a driver finds out about from a fine.
  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    String assignmentId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(companyControllerProvider.notifier)
        .confirm(assignmentId);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.companyHandoverConfirmed)),
      );
    } else if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              l10n,
              failureOf(ref.read(companyControllerProvider)),
            ),
          ),
        ),
      );
    }
  }
}
