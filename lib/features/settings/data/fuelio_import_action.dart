import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/files/file_text.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/vehicle.dart';
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

  // Offered only when the file names no station anywhere. Fuelio's export has
  // a City and a StationID column and leaves both empty, so every fill-up
  // arrives with nowhere attached and the only fix was editing them one by
  // one. Asked here because the file has already been parsed, so whether it is
  // worth asking is known before the form opens.
  final askForStation = backup.fillUps.isNotEmpty && !backup.hasAnyStation;
  final options = await showAdaptiveEntrySheet<_ImportOptions>(
    context,
    (_) => _ImportOptionsForm(
      vehicles: vehicles,
      createsVehicle: backup.vehicle?.name,
      askForStation: askForStation,
    ),
  );
  if (options == null || !context.mounted) {
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
    var target = options.vehicleId;
    if (target == null) {
      final created = await ref
          .read(vehicleRepositoryProvider)
          .create(
            vehicleFromFuelio(
              backup.vehicle!,
              householdId: household!.id,
              fuelTypeKey: options.fuelTypeKey,
              fillUps: backup.fillUps,
            ),
          );
      target = created.id;
      ref.invalidate(garageBootstrapProvider);
    }

    final result = await importFuelioBackup(
      ref: ref,
      vehicleId: target,
      backup: backup,
      defaultStation: askForStation ? options.station : null,
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

/// What the import was told before it ran: which car, or the fuel of the one
/// it creates, and where the fill-ups were bought when the file does not say.
typedef _ImportOptions = ({
  String? vehicleId,
  String fuelTypeKey,
  String station,
});

/// The questions an import asks before it runs, as a form like every other:
/// they were an `AlertDialog` opened from a sheet.
class _ImportOptionsForm extends StatefulWidget {
  const _ImportOptionsForm({
    required this.vehicles,
    required this.createsVehicle,
    required this.askForStation,
  });

  final List<Vehicle> vehicles;

  /// The name of the car the file carries, which the import creates when the
  /// garage has none to put the entries on.
  final String? createsVehicle;
  final bool askForStation;

  @override
  State<_ImportOptionsForm> createState() => _ImportOptionsFormState();
}

class _ImportOptionsFormState extends State<_ImportOptionsForm> {
  late String? _vehicleId = widget.vehicles.isEmpty
      ? null
      : widget.vehicles.first.id;
  String _fuelTypeKey = 'fuel_petrol';
  final _station = TextEditingController();

  @override
  void dispose() {
    _station.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EntrySheetBody(
      title: l10n.settingsImportFuelio,
      fields: [
        DiscardGuard(controllers: [_station]),
        Text(l10n.settingsImportFuelioHint),
        const SizedBox(height: GarageTokens.space4),
        if (widget.vehicles.isEmpty) ...[
          Text(l10n.settingsImportCreates(widget.createsVehicle!)),
          const SizedBox(height: GarageTokens.space4),
          // Fuelio does not record this in a form worth trusting, and a wrong
          // fuel type quietly distorts every economy figure, so it is asked
          // rather than guessed.
          LabeledField(
            label: l10n.settingsImportFuelType,
            child: DropdownButton<String>(
              value: _fuelTypeKey,
              isExpanded: true,
              items: [
                for (final key in fuelTypeKeys)
                  DropdownMenuItem(
                    value: key,
                    child: Text(fuelTypeLabel(l10n, key) ?? key),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _fuelTypeKey = value ?? _fuelTypeKey),
            ),
          ),
        ] else
          LabeledField(
            label: l10n.settingsImportVehicle,
            child: DropdownButton<String>(
              value: _vehicleId,
              isExpanded: true,
              items: [
                for (final vehicle in widget.vehicles)
                  DropdownMenuItem(
                    value: vehicle.id,
                    child: Text(vehicle.nickname),
                  ),
              ],
              onChanged: (value) => setState(() => _vehicleId = value),
            ),
          ),
        if (widget.askForStation) ...[
          const SizedBox(height: GarageTokens.space4),
          LabeledField(
            label: l10n.settingsImportStation,
            child: TextField(
              controller: _station,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: l10n.settingsImportStationHint,
              ),
            ),
          ),
        ],
      ],
      confirmLabel: l10n.settingsImportRun,
      onConfirm: () => Navigator.of(context).pop((
        vehicleId: _vehicleId,
        fuelTypeKey: _fuelTypeKey,
        station: _station.text,
      )),
      onCancel: () => Navigator.of(context).pop(),
      cancelLabel: l10n.commonCancel,
    );
  }
}
