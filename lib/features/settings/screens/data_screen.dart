import 'dart:convert';

import 'package:archive/archive.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/export/export_file_name.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/export/csv_export.dart';
import '../../../core/widgets/failure_message.dart';
import '../../documents/providers/document_providers.dart';
import '../../tyres/providers/tyre_providers.dart';
import '../../../core/format/unit_format.dart';
import '../providers/unit_providers.dart';
import '../../../core/files/backup_folder.dart';
import '../../../core/files/file_saver.dart';
import '../providers/auto_backup_providers.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/files/file_text.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/company/assignment_resolution.dart';
import '../../../domain/export/garage_backup.dart';
import '../../company/providers/company_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../household/providers/member_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/settings_providers.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../data/backup_action.dart';
import '../data/fuelio_import_action.dart';
import '../data/sample_data_action.dart';
import '../../observations/providers/observation_providers.dart';
import '../../trips/providers/route_providers.dart';

/// Getting data in and out: imports, exports, backups, and the read-only API.
///
/// Split out of Settings, where these were seven of its thirty-one rows and
/// none of them was a setting. A backup is a thing you do, not a preference you
/// hold, and burying "get my data out" below the theme picker made the app's
/// own no-lock-in promise harder to keep than to state.
class DataScreen extends ConsumerWidget {
  const DataScreen({super.key});

  /// The export, built once so saving and sharing cannot disagree about it.
  ///
  /// A zip of real tables, one file per vehicle per kind, rather than the
  /// twelve differently shaped tables that used to be concatenated into a
  /// single `.csv` with `#` comment lines between them. No spreadsheet or CSV
  /// parser opens that correctly; every one of them reads it as one broken
  /// table. The tyre history and the cars' own attributes are in here too —
  /// both were silently missing, and the tread series is the one history that
  /// cannot be reconstructed after the fact.
  Future<({Uint8List bytes, String fileName})> _csv(
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final vehicles = await ref.read(allVehiclesProvider.future);
    final archive = Archive();

    void add(String name, String csv) {
      final bytes = utf8.encode(csv);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('vehicles.csv', vehiclesToCsv(vehicles));
    // Read once for the whole garage: routes are household-scoped, and a trip
    // row wants the name rather than the id.
    final routeNames = {
      for (final route in await ref.read(routesProvider.future))
        route.id: route.name,
    };
    // Who had which car when, resolved once per entry into a name. Empty
    // off the plan, so a private garage's export gains a blank column and
    // nothing else.
    final assignments = await ref.read(fleetAssignmentsProvider.future);
    // The members are read on the plan, not once the log has a window: a
    // company before its first handover has a chooser to agree with too.
    final names = ref.read(companyPlanProvider)
        ? await ref.read(memberNamesProvider.future)
        : const <String, String>{};
    // The chooser lists this garage's members and shows Everyone for anyone
    // else; the sheets agree with it, so a driver chosen in another garage
    // does not come back as empty tables here. A driver is never offered
    // the chooser and gets everything they can read: the log they hold is
    // their own windows, so any other pick would be empty tables too.
    final chosen = ref.read(exportDriverFilterProvider);
    final filter = !ref.read(isDriverProvider) && names.containsKey(chosen)
        ? chosen
        : null;
    final used = <String>{};
    for (final vehicle in vehicles) {
      String? driverIdOn(DateTime date) => AssignmentResolution.driverOn(
        assignments,
        vehicleId: vehicle.id,
        on: date,
      );
      // A departed driver's window is still in the log while the member
      // list no longer names them; the sheet says so rather than leaving
      // the cell blank, which reads as a day nobody had the car.
      String driverOn(DateTime date) => AssignmentResolution.driverOf(
        assignments,
        names: names,
        vehicleId: vehicle.id,
        on: date,
        former: l10n.companyFormerMember,
      );
      // The per-driver export: only the entries that were theirs that day.
      List<T> theirs<T>(List<T> entries, DateTime Function(T) dateOf) => [
        for (final entry in entries)
          if (filter == null || driverIdOn(dateOf(entry)) == filter) entry,
      ];
      final fuel = await ref.read(rawFuelEntriesProvider(vehicle.id).future);
      final services = await ref.read(
        serviceEntriesProvider(vehicle.id).future,
      );
      // Every kind the CSV importer can read, so what a household brings in
      // from another app is what it can take back out.
      final costs = await ref.read(costEntriesProvider(vehicle.id).future);
      final income = await ref.read(incomeEntriesProvider(vehicle.id).future);
      final trips = await ref.read(tripEntriesProvider(vehicle.id).future);
      final readings = await ref.read(
        odometerEntriesProvider(vehicle.id).future,
      );
      final tyres = await ref.read(tyreSetsProvider(vehicle.id).future);
      final documents = await ref.read(
        vehicleDocumentsProvider(vehicle.id).future,
      );
      final observations = await ref.read(
        observationsProvider(vehicle.id).future,
      );

      // Two cars called "Golf" would otherwise write over each other inside
      // the zip.
      // Transliterated, not stripped: "Škoda" became "koda" and "Đuro"
      // became "uro", which reads as a corrupted file rather than a slugged
      // one. Two cars called Golf are `golf` and `golf-2`.
      final slug = uniqueName(vehicleSlug(vehicle.nickname), used);

      // Tyres, documents and the cars themselves are the car's, not a
      // day's, so they stay whole whoever the export is for.
      final tables = <(String, String)>[
        (
          'fuel',
          fuelEntriesToCsv(
            theirs(fuel, (e) => e.date),
            vehicleName: vehicle.nickname,
            driverOn: driverOn,
          ),
        ),
        (
          'service',
          serviceEntriesToCsv(
            theirs(services, (e) => e.date),
            vehicleName: vehicle.nickname,
            driverOn: driverOn,
          ),
        ),
        (
          'cost',
          costEntriesToCsv(
            theirs(costs, (e) => e.date),
            vehicleName: vehicle.nickname,
            driverOn: driverOn,
          ),
        ),
        (
          'income',
          incomeEntriesToCsv(
            theirs(income, (e) => e.date),
            vehicleName: vehicle.nickname,
            driverOn: driverOn,
          ),
        ),
        (
          'trip',
          tripEntriesToCsv(
            theirs(trips, (e) => e.date),
            vehicleName: vehicle.nickname,
            routeNames: routeNames,
            driverOn: driverOn,
          ),
        ),
        (
          'odometer',
          odometerEntriesToCsv(
            theirs(readings, (e) => e.date),
            vehicleName: vehicle.nickname,
            driverOn: driverOn,
          ),
        ),
        ('tyres', tyreSetsToCsv(tyres, vehicleName: vehicle.nickname)),
        ('documents', documentsToCsv(documents, vehicleName: vehicle.nickname)),
        (
          'observations',
          observationsToCsv(
            theirs(observations, (o) => o.noticedOn),
            vehicleName: vehicle.nickname,
            driverOn: driverOn,
          ),
        ),
      ];
      for (final (kind, csv) in tables) {
        add('$slug-$kind.csv', csv);
      }
    }

    final zipped = ZipEncoder().encode(archive);
    return (
      bytes: Uint8List.fromList(zipped),
      fileName: exportFileName(ExportKind.csv, on: DateTime.now()),
    );
  }

  /// Writes the CSV wherever the user points the save dialog.
  ///
  /// Saving rather than sharing is the default because "get my data out" is
  /// about *having a file*, and the share sheet made that a detour through
  /// whichever app happened to accept it — then renamed it on the way.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final ({Uint8List bytes, String fileName}) csv;
    final bool saved;
    try {
      csv = await _csv(ref, l10n);
      saved = await ref.read(fileSaverProvider)(
        fileName: csv.fileName,
        bytes: csv.bytes,
        mimeType: 'application/zip',
      );
    } catch (error) {
      // Eight per-vehicle reads and a zip: a throw from any of them used to
      // be an unhandled future, and the tap looked like it had done nothing.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
        );
      }
      return;
    }
    if (!context.mounted || !saved) {
      // Backing out is not a failure and must not be reported as a success.
      return;
    }
    ScaffoldMessenger.of(
      context,
      // Named: a silent success and a silent failure looked the same.
    ).showSnackBar(
      SnackBar(content: Text(l10n.settingsExportDone(csv.fileName))),
    );
  }

  /// Still offered, because some people do want it straight into a chat and
  /// taking that away to fix the default would trade one complaint for another.
  Future<void> _shareExport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final ({Uint8List bytes, String fileName}) csv;
    try {
      csv = await _csv(ref, l10n);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
        );
      }
      return;
    }
    // `fileNameOverrides`, not just `name`: `XFile.fromData` drops its name on
    // every platform except web (share_plus documents this), and share_plus
    // then falls back to a UUID — which is why every export arrived called
    // something like `3f9a1c-8e21.csv`.
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            csv.bytes,
            name: csv.fileName,
            // The export became a zip; share targets filter on the MIME type,
            // and some refuse a mismatch outright.
            mimeType: 'application/zip',
          ),
        ],
        fileNameOverrides: [csv.fileName],
        subject: l10n.settingsExport,
      ),
    );
  }

  /// A file that comes back, which the CSV export cannot: a CSV loses which
  /// service types a visit covered and whether a tank was full, so it can be
  /// read but not restored.
  Future<({Uint8List bytes, String fileName})?> _backupFile(
    WidgetRef ref,
  ) async {
    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null) {
      return null;
    }
    final json = await buildBackup(ref: ref, householdName: household.name);
    return (
      bytes: Uint8List.fromList(utf8.encode(json)),
      fileName: exportFileName(ExportKind.backup, on: DateTime.now()),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final backup = await _backupFile(ref);
    if (backup == null || !context.mounted) {
      return;
    }
    final saved = await ref.read(fileSaverProvider)(
      fileName: backup.fileName,
      bytes: backup.bytes,
      mimeType: 'application/json',
    );
    if (!context.mounted || !saved) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.settingsBackupDone(backup.fileName))),
    );
  }

  Future<void> _shareBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final backup = await _backupFile(ref);
    if (backup == null) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            backup.bytes,
            name: backup.fileName,
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: [backup.fileName],
        subject: l10n.settingsBackup,
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final file = await ref.read(restoreFilePickerProvider)();
    if (file == null || !context.mounted) {
      return;
    }
    final RestoredBackup backup;
    try {
      backup = GarageBackup.decode(await readTextFile(file));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsRestoreNotABackup)));
      }
      return;
    }

    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null || !context.mounted) {
      return;
    }
    // Taken before the await, so the sentence lands even if the page is
    // gone by then. A restore that fails part-way, or the free cap the
    // restore raises before creating anything, used to be an unhandled
    // exception here: the picker closed and nothing was said. The Fuelio
    // import's shape, and through failureMessage so the cause is recorded.
    final messenger = ScaffoldMessenger.of(context);
    final RestoreResult result;
    try {
      result = await restoreBackup(
        ref: ref,
        householdId: household.id,
        backup: backup,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.settingsRestoreDone(
            result.vehiclesCreated + result.vehiclesMatched,
            result.entriesWritten,
            result.entriesSkipped,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasSomethingToExport =
        (ref.watch(allVehiclesProvider).value ?? const []).isNotEmpty;

    return GaragePageScaffold(
      title: l10n.settingsData,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          // Grouped, because six undivided rows mixed bringing data in with
          // taking it out, and the two imports — the rows a new person is
          // most likely to need and most likely to fear — were the only ones
          // that explained nothing.
          Text(
            l10n.settingsDataBringIn.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.settingsImportFuelio),
            subtitle: Text(l10n.settingsImportFuelioHint),
            isThreeLine: true,
            onTap: () => importFuelioWithFeedback(context, ref),
          ),
          // The general answer beside the one-tap one: Fuelio's format is
          // known, and everything else needs the user to say which column is
          // which.
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l10n.settingsImportCsv),
            subtitle: Text(l10n.settingsImportCsvHint),
            isThreeLine: true,
            onTap: () => context.push('/import'),
          ),
          ListTile(
            key: const Key('settings-restore'),
            leading: const Icon(Icons.settings_backup_restore),

            // Restoring is bringing data in, whatever file it comes from.
            title: Text(l10n.settingsRestore),
            subtitle: Text(l10n.settingsRestoreHint),
            onTap: () => _restore(context, ref),
          ),
          // Only where a folder grant can outlive the picker: SAF is an Android
          // concept and a web page cannot hold write access to a directory
          // across sessions, so on the web this offers nothing rather than
          // offering something that cannot work.
          const SizedBox(height: GarageTokens.space4),
          Text(
            l10n.settingsDataTakeOut.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          if (backupFoldersSupported)
            Consumer(
              builder: (context, ref, _) {
                final folder = ref.watch(autoBackupFolderProvider).value;
                final lastRun = ref.watch(autoBackupLastRunProvider).value;
                final failed =
                    ref.watch(autoBackupFailedProvider).value ?? false;
                return ListTile(
                  key: const Key('settings-auto-backup'),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(l10n.settingsAutoBackup),
                  subtitle: Text(
                    folder == null
                        ? l10n.settingsAutoBackupOff
                        : failed
                        ? l10n.settingsAutoBackupFailed
                        : lastRun == null
                        ? l10n.settingsAutoBackupNever
                        : l10n.settingsAutoBackupOn(
                            UnitFormat(
                              locale: Localizations.localeOf(
                                context,
                              ).languageCode,
                              preferences: ref.read(unitPreferencesProvider),
                            ).formatDate(lastRun),
                          ),
                  ),
                  // An icon, as the backup row's share is: "Prekini kopiranje"
                  // as a text button left a 320-pixel phone at 1.5x no room
                  // for the title at all.
                  trailing: folder == null
                      ? null
                      : IconButton(
                          key: const Key('settings-auto-backup-stop'),
                          icon: const Icon(Icons.folder_off_outlined),
                          tooltip: l10n.settingsAutoBackupStop,
                          onPressed: () => ref
                              .read(autoBackupFolderProvider.notifier)
                              .forget(),
                        ),
                  onTap: () =>
                      ref.read(autoBackupFolderProvider.notifier).choose(),
                );
              },
            ),
          ListTile(
            key: const Key('settings-backup'),
            enabled: hasSomethingToExport,
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.settingsBackup),
            subtitle: Text(l10n.settingsBackupHint),
            // Tapping the row saves; sharing is beside it rather than instead
            // of it. Two affordances, and the common case costs no extra tap.
            trailing: IconButton(
              key: const Key('settings-backup-share'),
              icon: const Icon(Icons.ios_share),
              tooltip: l10n.commonShare,
              onPressed: hasSomethingToExport
                  ? () => _shareBackup(context, ref)
                  : null,
            ),
            onTap: hasSomethingToExport ? () => _backup(context, ref) : null,
          ),
          // Whose entries the spreadsheets hold. Only where there is a log
          // to read it off: a private garage has no drivers to choose
          // between, and its export keeps the column blank. Not for a
          // driver, whose rows are their own.
          if (ref.watch(companyPlanProvider) && !ref.watch(isDriverProvider))
            Consumer(
              builder: (context, ref, _) {
                final members = ref.watch(membersProvider).value ?? const [];
                final filter = ref.watch(exportDriverFilterProvider);
                return ListTile(
                  key: const Key('export-driver-filter'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.exportDriverFilter),
                  // Capped and expanded like the currency row: a name is as
                  // long as its owner likes, and at a large font it pushed
                  // the row past the edge of a narrow phone.
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      // Everyone until the member list names the driver:
                      // the button insists its value is one of its rows.
                      value: members.any((member) => member.userId == filter)
                          ? filter
                          : null,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.exportDriverEveryone),
                        ),
                        for (final member in members)
                          DropdownMenuItem<String?>(
                            value: member.userId,
                            child: Text(
                              member.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          ref.read(exportDriverFilterProvider.notifier).state =
                              value,
                    ),
                  ),
                );
              },
            ),
          // Disabled rather than hidden: someone looking for their export
          // needs to know it exists and what is missing, not to wonder whether
          // the app has one at all.
          ListTile(
            enabled: hasSomethingToExport,
            leading: const Icon(Icons.download),
            title: Text(l10n.settingsExport),
            subtitle: Text(
              hasSomethingToExport
                  ? l10n.settingsExportHint
                  : l10n.settingsExportNothing,
            ),
            isThreeLine: hasSomethingToExport,
            trailing: IconButton(
              key: const Key('settings-export-share'),
              icon: const Icon(Icons.ios_share),
              tooltip: l10n.commonShare,
              onPressed: hasSomethingToExport
                  ? () => _shareExport(context, ref)
                  : null,
            ),
            onTap: hasSomethingToExport ? () => _export(context, ref) : null,
          ),
          // Above the destructive pair on purpose: loading a demo and wiping
          // everything are opposite acts, and the one that adds should not sit
          // among the ones that remove.
          Builder(
            builder: (context) {
              final loading = ref.watch(sampleDataLoadingProvider);
              return ListTile(
                leading: loading
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                title: Text(l10n.settingsSampleData),
                subtitle: Text(l10n.settingsSampleDataHint),
                // Untappable while it runs. The write takes seconds against a
                // real backend and used to give no sign it had started.
                enabled: !loading,
                onTap: () => loadSampleDataWithFeedback(context, ref),
              );
            },
          ),
          const SizedBox(height: GarageTokens.space6),
          // Last, under its own heading: this list is opened for import and
          // backup, and a key for scripts was its first row.
          Text(
            l10n.settingsForDevelopers.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: Text(l10n.apiTitle),
            subtitle: Text(l10n.apiHint),
            onTap: () => context.push('/api'),
          ),
        ],
      ),
    );
  }
}
