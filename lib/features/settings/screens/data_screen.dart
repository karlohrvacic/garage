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
import '../../../domain/export/garage_backup.dart';
import '../../household/providers/household_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../data/backup_action.dart';
import '../data/fuelio_import_action.dart';
import '../data/sample_data_action.dart';

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
  Future<({Uint8List bytes, String fileName})> _csv(WidgetRef ref) async {
    final vehicles = await ref.read(allVehiclesProvider.future);
    final archive = Archive();

    void add(String name, String csv) {
      final bytes = utf8.encode(csv);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('vehicles.csv', vehiclesToCsv(vehicles));
    final used = <String>{};
    for (final vehicle in vehicles) {
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

      // Two cars called "Golf" would otherwise write over each other inside
      // the zip.
      var slug = _fileSlug(vehicle.nickname);
      if (!used.add(slug)) {
        var suffix = 2;
        while (!used.add('$slug-$suffix')) {
          suffix++;
        }
        slug = '$slug-$suffix';
      }

      final tables = <(String, String)>[
        ('fuel', fuelEntriesToCsv(fuel, vehicleName: vehicle.nickname)),
        (
          'service',
          serviceEntriesToCsv(services, vehicleName: vehicle.nickname),
        ),
        ('cost', costEntriesToCsv(costs, vehicleName: vehicle.nickname)),
        ('income', incomeEntriesToCsv(income, vehicleName: vehicle.nickname)),
        ('trip', tripEntriesToCsv(trips, vehicleName: vehicle.nickname)),
        (
          'odometer',
          odometerEntriesToCsv(readings, vehicleName: vehicle.nickname),
        ),
        ('tyres', tyreSetsToCsv(tyres, vehicleName: vehicle.nickname)),
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

  /// A file name inside the zip: lower case, no spaces, nothing a file system
  /// argues about.
  static String _fileSlug(String name) {
    // Transliterated, not stripped: "Škoda" became "koda" and "Đuro" became
    // "uro", which reads as a corrupted file rather than a slugged one.
    const folded = {'č': 'c', 'ć': 'c', 'ž': 'z', 'š': 's', 'đ': 'd'};
    final slug = folded.entries
        .fold(name.toLowerCase(), (text, e) => text.replaceAll(e.key, e.value))
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'vehicle' : slug;
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
      csv = await _csv(ref);
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
      csv = await _csv(ref);
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
    final result = await restoreBackup(
      ref: ref,
      householdId: household.id,
      backup: backup,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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
                return ListTile(
                  key: const Key('settings-auto-backup'),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(l10n.settingsAutoBackup),
                  subtitle: Text(
                    folder == null
                        ? l10n.settingsAutoBackupOff
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
                  trailing: folder == null
                      ? null
                      : TextButton(
                          key: const Key('settings-auto-backup-stop'),
                          onPressed: () => ref
                              .read(autoBackupFolderProvider.notifier)
                              .forget(),
                          child: Text(l10n.settingsAutoBackupStop),
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
