import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/export/csv_export.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/export/garage_backup.dart';
import '../../household/providers/household_providers.dart';
import '../../stations/providers/station_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
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

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = await ref.read(allVehiclesProvider.future);
    final buffer = StringBuffer();
    for (final vehicle in vehicles) {
      final fuel = await ref.read(rawFuelEntriesProvider(vehicle.id).future);
      final services = await ref.read(
        serviceEntriesProvider(vehicle.id).future,
      );
      buffer.writeln('# ${vehicle.nickname} — fuel');
      buffer.writeln(fuelEntriesToCsv(fuel, vehicleName: vehicle.nickname));
      buffer.writeln();
      buffer.writeln('# ${vehicle.nickname} — service');
      buffer.writeln(
        serviceEntriesToCsv(services, vehicleName: vehicle.nickname),
      );
      buffer.writeln();
    }

    final file = XFile.fromData(
      utf8.encode(buffer.toString()),
      name: 'garage-export.csv',
      mimeType: 'text/csv',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: l10n.settingsExport),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsExportDone)));
    }
  }

  /// A file that comes back, which the CSV export cannot: a CSV loses which
  /// service types a visit covered and whether a tank was full, so it can be
  /// read but not restored.
  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null || !context.mounted) {
      return;
    }
    final json = await buildBackup(ref: ref, householdName: household.name);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(json),
            name: 'garage-backup.json',
            mimeType: 'application/json',
          ),
        ],
        subject: l10n.settingsBackup,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsBackupDone)));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final file = await ref.read(restoreFilePickerProvider)();
    if (file == null || !context.mounted) {
      return;
    }
    final RestoredBackup backup;
    try {
      backup = GarageBackup.decode(await file.readAsString());
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

  /// Asks for location, having just explained what it buys.
  Future<void> _enablePumpAutofill(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ref.read(requestLocationProvider)();
    ref.invalidate(locationGrantedStateProvider);
    if (!granted) {
      // Android only shows the system dialog once; after that the only way
      // back is the system settings, so say so rather than doing nothing.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsPumpAutofillDenied)),
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
          ListTile(
            leading: const Icon(Icons.api),
            title: Text(l10n.apiTitle),
            subtitle: Text(l10n.apiHint),
            onTap: () => context.push('/api'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.settingsImportFuelio),
            onTap: () => importFuelioWithFeedback(context, ref),
          ),
          // The general answer beside the one-tap one: Fuelio's format is
          // known, and everything else needs the user to say which column is
          // which.
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l10n.settingsImportCsv),
            onTap: () => context.push('/import'),
          ),
          ListTile(
            key: const Key('settings-restore'),
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l10n.settingsRestore),
            subtitle: Text(l10n.settingsRestoreHint),
            onTap: () => _restore(context, ref),
          ),
          ListTile(
            key: const Key('settings-backup'),
            enabled: hasSomethingToExport,
            leading: const Icon(Icons.save_alt),
            title: Text(l10n.settingsBackup),
            subtitle: Text(l10n.settingsBackupHint),
            onTap: hasSomethingToExport ? () => _backup(context, ref) : null,
          ),
          // Disabled rather than hidden: someone looking for their export
          // needs to know it exists and what is missing, not to wonder whether
          // the app has one at all.
          ListTile(
            enabled: hasSomethingToExport,
            leading: const Icon(Icons.download),
            title: Text(l10n.settingsExport),
            subtitle: hasSomethingToExport
                ? null
                : Text(l10n.settingsExportNothing),
            onTap: hasSomethingToExport ? () => _export(context, ref) : null,
          ),
          // Play requires a reachable privacy policy, and the Data safety form
          // declares this exact URL; the app has to link it too.
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.settingsPrivacyPolicy),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => ref.read(urlOpenerProvider)(GarageLinks.privacyPolicy),
          ),
          // Above the destructive pair on purpose: loading a demo and wiping
          // everything are opposite acts, and the one that adds should not sit
          // among the ones that remove.
          // Offered here with the reason attached, rather than as a system
          // dialog that appears the first time someone opens the fill-up
          // sheet. A permission asked for out of context is a permission
          // declined.
          Consumer(
            builder: (context, ref, _) {
              final granted = ref.watch(locationGrantedStateProvider);
              return ListTile(
                leading: const Icon(Icons.my_location_outlined),
                title: Text(l10n.settingsPumpAutofill),
                subtitle: Text(
                  granted.value ?? false
                      ? l10n.settingsPumpAutofillOn
                      : l10n.settingsPumpAutofillHint,
                ),
                trailing: (granted.value ?? false)
                    ? Icon(Icons.check_circle, color: context.tokens.accent)
                    : null,
                enabled: !(granted.value ?? false),
                onTap: () => _enablePumpAutofill(context, ref),
              );
            },
          ),
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
        ],
      ),
    );
  }
}
