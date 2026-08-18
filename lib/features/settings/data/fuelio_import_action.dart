import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/files/file_text.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/dialog_actions.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/import/fuelio_backup.dart';
import '../../household/providers/household_providers.dart';
import '../../vehicles/fuel_type_labels.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'fuelio_import.dart';

/// Picks a Fuelio backup and imports it, reporting the outcome to the user.
///
/// Public and out here rather than private to the settings screen because the
/// dashboard's empty state offers the same thing: arriving from Fuelio is one
/// of the ways a garage gets its first vehicle, and burying it three taps into
/// Settings hid it from exactly the person who needs it. Same shape as
/// [loadSampleDataWithFeedback] next door.
Future<void> importFuelioWithFeedback(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;

  // The file comes first, before any check on what the household owns: a
  // Fuelio backup carries its own vehicle, so needing a car before importing
  // had it backwards — importing is how someone arriving from Fuelio gets
  // their first one.
  final file = await ref.read(backupFilePickerProvider)();
  if (file == null || !context.mounted) {
    return;
  }
  final backup = parseFuelioBackup(await readTextFile(file));
  final vehicles = await ref.read(allVehiclesProvider.future);
  if (!context.mounted) {
    return;
  }

  if (vehicles.isEmpty && backup.vehicle == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsImportNoVehicle)));
    return;
  }

  String? vehicleId = vehicles.isEmpty ? null : vehicles.first.id;
  var fuelTypeKey = 'fuel_petrol';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
        title: Text(l10n.settingsImportFuelio),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsImportFuelioHint),
            const SizedBox(height: GarageTokens.space4),
            if (vehicles.isEmpty) ...[
              Text(l10n.settingsImportCreates(backup.vehicle!.name)),
              const SizedBox(height: GarageTokens.space4),
              // Fuelio does not record this in a form worth trusting, and a
              // wrong fuel type quietly distorts every economy figure, so it
              // is asked rather than guessed.
              LabeledField(
                label: l10n.settingsImportFuelType,
                child: DropdownButton<String>(
                  value: fuelTypeKey,
                  isExpanded: true,
                  items: [
                    for (final key in fuelTypeKeys)
                      DropdownMenuItem(
                        value: key,
                        child: Text(fuelTypeLabel(l10n, key) ?? key),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => fuelTypeKey = value ?? fuelTypeKey),
                ),
              ),
            ] else ...[
              Text(
                l10n.settingsImportVehicle,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              DropdownButton<String>(
                value: vehicleId,
                isExpanded: true,
                items: [
                  for (final vehicle in vehicles)
                    DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(vehicle.nickname),
                    ),
                ],
                onChanged: (value) => setState(() => vehicleId = value),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsImportRun),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  // Captured before the first await, and popped in a `finally`.
  //
  // This used to dismiss the spinner through `context`, guarded by
  // `context.mounted` — and the import is precisely the thing that unmounts
  // it. Creating the household's first car invalidates the vehicle providers,
  // which swaps out the empty state the import was started from, so the guard
  // saw an unmounted context, returned early, and left a barrier-blocking
  // spinner up with no way to dismiss it. The import had in fact succeeded.
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  var spinnerUp = true;
  void dismissSpinner() {
    if (spinnerUp) {
      spinnerUp = false;
      navigator.pop();
    }
  }

  try {
    final household = await ref.read(currentHouseholdProvider.future);
    var target = vehicleId;
    if (target == null) {
      final created = await ref
          .read(vehicleRepositoryProvider)
          .create(
            vehicleFromFuelio(
              backup.vehicle!,
              householdId: household!.id,
              fuelTypeKey: fuelTypeKey,
              fillUps: backup.fillUps,
            ),
          );
      target = created.id;
      ref.invalidate(allVehiclesProvider);
      ref.invalidate(vehiclesProvider);
    }

    final result = await importFuelioBackup(
      ref: ref,
      vehicleId: target,
      backup: backup,
    );
    dismissSpinner();
    final summary = l10n.settingsImportDone(
      result.fillUps,
      result.services,
      result.costs,
      result.reminders,
    );
    final skipped = result.skippedReminders.isEmpty
        ? ''
        : '\n${l10n.settingsImportSkipped(result.skippedReminders.join(', '))}';
    messenger.showSnackBar(SnackBar(content: Text('$summary$skipped')));
  } catch (error) {
    // Through failureMessage, so the cause is recorded rather than replaced
    // by a generic sentence and forgotten.
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
  } finally {
    // Whatever happened, the spinner comes down. A modal with no barrier to
    // tap is the one dialog a user cannot get out of.
    dismissSpinner();
  }
}
