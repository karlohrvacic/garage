import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/files/file_picker.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/export/csv_export.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/household.dart';
import '../../../domain/maintenance/tracking_level.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/fuel_type_labels.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../../domain/import/fuelio_backup.dart';
import '../data/fuelio_import.dart';
import '../providers/settings_providers.dart';

/// Currencies offered for a household's records. Europe first, because that is
/// where the app is used, then the majors. A household whose currency is not
/// here keeps whatever is stored — the dropdown falls back to null rather than
/// silently converting anyone's history.
const _currencies = [
  'EUR',
  'BAM',
  'RSD',
  'MKD',
  'ALL',
  'CHF',
  'GBP',
  'PLN',
  'CZK',
  'HUF',
  'RON',
  'BGN',
  'SEK',
  'NOK',
  'DKK',
  'ISK',
  'TRY',
  'UAH',
  'USD',
  'CAD',
  'AUD',
  'NZD',
  'JPY',
];

/// ISO 3166-1 alpha-2 for the "elsewhere" choice: user-assigned, so it can
/// never collide with a real country the app later ships rules for.
const _elsewhere = 'ZZ';

/// Countries by their own name, which needs no translating. The list is short
/// on purpose — it exists to keep one country's statutory items off another
/// country's screens, and grows when verified rules for a market are added.
const _countries = {
  'HR': 'Hrvatska',
  'SI': 'Slovenija',
  'BA': 'Bosna i Hercegovina',
  'RS': 'Srbija',
  'AT': 'Österreich',
  'DE': 'Deutschland',
  'IT': 'Italia',
  'GB': 'United Kingdom',
  'US': 'United States',
  _elsewhere: 'Elsewhere',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Household _with(
    Household base, {
    String? distanceUnit,
    String? volumeUnit,
    String? currencyCode,
    int? bundlingWindowDays,
    int? bundlingWindowKm,
    String? trackingLevel,
    String? countryCode,
  }) {
    return Household(
      id: base.id,
      name: base.name,
      currencyCode: currencyCode ?? base.currencyCode,
      distanceUnit: distanceUnit ?? base.distanceUnit,
      volumeUnit: volumeUnit ?? base.volumeUnit,
      bundlingWindowDays: bundlingWindowDays ?? base.bundlingWindowDays,
      bundlingWindowKm: bundlingWindowKm ?? base.bundlingWindowKm,
      trackingLevel: trackingLevel ?? base.trackingLevel,
      countryCode: countryCode ?? base.countryCode,
    );
  }

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

  Future<void> _importFuelio(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;

    // The file comes first, before any check on what the household owns: a
    // Fuelio backup carries its own vehicle, so needing a car before importing
    // had it backwards — importing is how someone arriving from Fuelio gets
    // their first one.
    final file = await ref.read(backupFilePickerProvider)();
    if (file == null || !context.mounted) {
      return;
    }
    final backup = parseFuelioBackup(await file.readAsString());
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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
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
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      final summary = l10n.settingsImportDone(
        result.fillUps,
        result.services,
        result.costs,
        result.reminders,
      );
      final skipped = result.skippedReminders.isEmpty
          ? ''
          : '\n${l10n.settingsImportSkipped(result.skippedReminders.join(', '))}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$summary$skipped')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pop();
      // Through failureMessage, so the cause is recorded rather than replaced
      // by a generic sentence and forgotten.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeleteConfirmTitle),
        content: Text(l10n.settingsDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsDeleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(currentHouseholdProvider).value;
    final identity = ref.watch(accountIdentityProvider);
    final hasSomethingToExport =
        (ref.watch(allVehiclesProvider).value ?? const []).isNotEmpty;
    final locale = ref.watch(localeProvider);

    void save(Household Function(Household) patch) =>
        ref.read(settingsControllerProvider.notifier).save(patch);

    return GarageTabScaffold(
      current: GarageTab.settings,
      title: l10n.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          // Which account this is. Signing in with Google never asks for an
          // address, so without this there is nowhere in the app that answers
          // "who am I signed in as?" — which matters most on the screen that
          // also offers to sign out and delete the account.
          if (identity != null) ...[
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    identity.name.characters.firstOrNull?.toUpperCase() ?? '?',
                  ),
                ),
                title: Text(identity.name),
                subtitle: identity.email.isEmpty ? null : Text(identity.email),
                // On the account it acts on, rather than in a list of data
                // actions below the fold — signing out is something people
                // look for next to their own name.
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: Text(l10n.settingsSignOut),
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space2),
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.householdTitle),
              subtitle: household == null ? null : Text(household.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/household'),
            ),
          ),
          const SizedBox(height: GarageTokens.space2),
          if (household != null) ...[
            _SectionTitle(l10n.settingsUnits, note: l10n.settingsUnitsHint),
            ListTile(
              title: Text(l10n.settingsDistance),
              trailing: DropdownButton<String>(
                value: household.distanceUnit,
                items: const [
                  DropdownMenuItem(value: 'km', child: Text('km')),
                  DropdownMenuItem(value: 'mi', child: Text('mi')),
                ],
                onChanged: (value) =>
                    save((base) => _with(base, distanceUnit: value)),
              ),
            ),
            ListTile(
              title: Text(l10n.settingsVolume),
              trailing: DropdownButton<String>(
                value: household.volumeUnit,
                items: const [
                  DropdownMenuItem(value: 'liter', child: Text('l')),
                  DropdownMenuItem(value: 'us_gallon', child: Text('US gal')),
                  DropdownMenuItem(value: 'uk_gallon', child: Text('UK gal')),
                ],
                onChanged: (value) =>
                    save((base) => _with(base, volumeUnit: value)),
              ),
            ),
            ListTile(
              title: Text(l10n.settingsCurrency),
              trailing: DropdownButton<String>(
                value: _currencies.contains(household.currencyCode)
                    ? household.currencyCode
                    : null,
                items: [
                  for (final code in _currencies)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (value) =>
                    save((base) => _with(base, currencyCode: value)),
              ),
            ),
            const Divider(),
            _SectionTitle(
              l10n.settingsBundling,
              note: l10n.settingsBundlingHint,
            ),
            ListTile(
              title: Text(l10n.settingsBundlingWindowDays),
              trailing: _Stepper(
                value: household.bundlingWindowDays,
                step: 7,
                max: 365,
                onChanged: (value) =>
                    save((base) => _with(base, bundlingWindowDays: value)),
              ),
            ),
            ListTile(
              title: Text(l10n.settingsBundlingWindowKm),
              trailing: _Stepper(
                value: household.bundlingWindowKm,
                step: 100,
                max: 100000,
                onChanged: (value) =>
                    save((base) => _with(base, bundlingWindowKm: value)),
              ),
            ),
            const Divider(),
            _SectionTitle(l10n.settingsCountry, note: l10n.settingsCountryHint),
            // Full width rather than a ListTile trailing: country names run
            // long enough ("Bosna i Hercegovina") to consume the whole tile.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GarageTokens.space4,
                vertical: GarageTokens.space2,
              ),
              child: LabeledField(
                label: l10n.settingsCountry,
                child: DropdownButtonFormField<String>(
                  initialValue: _countries.containsKey(household.countryCode)
                      ? household.countryCode
                      : _elsewhere,
                  isExpanded: true,
                  items: [
                    for (final entry in _countries.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.key == _elsewhere
                              ? l10n.countryElsewhere
                              : entry.value,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      save((base) => _with(base, countryCode: value));
                    }
                  },
                ),
              ),
            ),
            const Divider(),
            _SectionTitle(l10n.settingsTracking),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GarageTokens.space4,
              ),
              child: Text(
                l10n.settingsTrackingHint,
                style: TextStyle(color: context.tokens.muted),
              ),
            ),
            RadioGroup<String>(
              groupValue: household.trackingLevel,
              onChanged: (level) {
                if (level != null) {
                  save((base) => _with(base, trackingLevel: level));
                }
              },
              child: Column(
                children: [
                  for (final level in TrackingLevel.values)
                    RadioListTile<String>(
                      value: level.key,
                      title: Text(switch (level) {
                        TrackingLevel.beginner => l10n.trackingBeginner,
                        TrackingLevel.intermediate => l10n.trackingIntermediate,
                        TrackingLevel.advanced => l10n.trackingAdvanced,
                      }),
                      // Naming the fields each level adds, because "Detailed"
                      // and "Full" say nothing about what changes in the form.
                      subtitle: Text(switch (level) {
                        TrackingLevel.beginner =>
                          l10n.settingsTrackingBasicHint,
                        TrackingLevel.intermediate =>
                          l10n.settingsTrackingDetailedHint,
                        TrackingLevel.advanced => l10n.settingsTrackingFullHint,
                      }),
                    ),
                ],
              ),
            ),
            const Divider(),
          ],
          _SectionTitle(l10n.settingsTheme),
          RadioGroup<ThemeMode>(
            groupValue: ref.watch(themeModeProvider),
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeModeProvider.notifier).setMode(mode);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text(l10n.settingsThemeSystem),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text(l10n.settingsThemeLight),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text(l10n.settingsThemeDark),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionTitle(l10n.settingsLanguage),
          RadioGroup<String>(
            groupValue: locale?.languageCode ?? 'system',
            onChanged: (value) {
              final controller = ref.read(localeProvider.notifier);
              controller.setLocale(value == 'system' ? null : Locale(value!));
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'system',
                  title: Text(l10n.settingsLanguageSystem),
                ),
                const RadioListTile<String>(
                  value: 'en',
                  title: Text('English'),
                ),
                const RadioListTile<String>(
                  value: 'hr',
                  title: Text('Hrvatski'),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionTitle(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.api),
            title: Text(l10n.apiTitle),
            subtitle: Text(l10n.apiHint),
            onTap: () => context.push('/api'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(l10n.settingsImportFuelio),
            onTap: () => _importFuelio(context, ref),
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
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutTitle),
            onTap: () => context.push('/about'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever, color: context.tokens.danger),
            title: Text(
              l10n.settingsDeleteAccount,
              style: TextStyle(color: context.tokens.danger),
            ),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.note});

  final String title;

  /// What this group of settings changes. A heading alone leaves someone
  /// guessing what a number like "21 days" is going to do to their app.
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: GarageTokens.space2,
        bottom: GarageTokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title.toUpperCase(), style: GarageTheme.eyebrow(context)),
          if (note != null) ...[
            const SizedBox(height: GarageTokens.space1),
            Text(
              note!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.step,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int step;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value - step >= 0 ? () => onChanged(value - step) : null,
        ),
        Text('$value'),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}
