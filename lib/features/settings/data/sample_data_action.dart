import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../domain/demo/sample_garage.dart';
import '../../household/providers/household_providers.dart';
import 'sample_data_loader.dart';

/// Whether a sample-data load is in flight.
///
/// The load writes a vehicle, twelve fill-ups, two services, three costs and
/// two rules one row at a time, which is seconds against a real backend. While
/// it ran, nothing on screen changed: the first person to try it tapped five
/// times and got five cars. Both places that offer it watch this to show
/// progress, and the action itself refuses to start twice, so the guard does
/// not depend on any screen remembering to disable its button.
final sampleDataLoadingProvider = NotifierProvider<SampleDataLoading, bool>(
  SampleDataLoading.new,
);

class SampleDataLoading extends Notifier<bool> {
  @override
  bool build() => false;

  /// Claims the right to run, or returns false because a load already has it.
  bool _begin() {
    if (state) {
      return false;
    }
    state = true;
    return true;
  }

  void _done() => state = false;
}

/// Loads the sample garage and says what happened, from wherever it is
/// offered.
///
/// Both the Settings row and the getting-started card call this, so the place a
/// new arrival is told about sample data and the place it lives cannot drift
/// apart.
Future<void> loadSampleDataWithFeedback(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Asked, because this used to be one tap from the dashboard and it writes a
  // demo car with a year of history straight into a real garage. The sample
  // car is a Renault Clio, which is a car the people this app was built for
  // actually own — so the accident is not "somebody got demo data", it is
  // "somebody now has two Clios and has to work out which is theirs".
  //
  // The car is named in the question for exactly that reason.
  final confirmed = await confirmAction(
    context,
    title: l10n.settingsSampleDataConfirmTitle,
    body: l10n.settingsSampleDataConfirmBody(sampleVehicleName),
    confirmLabel: l10n.settingsSampleData,
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  final loading = ref.read(sampleDataLoadingProvider.notifier);
  if (!loading._begin()) {
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null) {
      return;
    }
    await loadSampleData(ref: ref, householdId: household.id);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsSampleDataDone)),
    );
  } catch (error) {
    // Through failureMessage, so the cause is recorded rather than replaced by
    // a generic sentence and forgotten.
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
  } finally {
    loading._done();
  }
}
