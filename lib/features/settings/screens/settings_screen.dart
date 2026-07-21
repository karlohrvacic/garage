import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/export/csv_export.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../domain/entities/household.dart';
import '../../auth/providers/auth_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/settings_providers.dart';

const _currencies = ['EUR', 'USD', 'GBP', 'CHF'];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Household _with(
    Household base, {
    String? distanceUnit,
    String? volumeUnit,
    String? currencyCode,
    int? bundlingWindowDays,
    int? bundlingWindowKm,
  }) {
    return Household(
      id: base.id,
      name: base.name,
      currencyCode: currencyCode ?? base.currencyCode,
      distanceUnit: distanceUnit ?? base.distanceUnit,
      volumeUnit: volumeUnit ?? base.volumeUnit,
      bundlingWindowDays: bundlingWindowDays ?? base.bundlingWindowDays,
      bundlingWindowKm: bundlingWindowKm ?? base.bundlingWindowKm,
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = await ref.read(vehiclesProvider.future);
    final buffer = StringBuffer();
    for (final vehicle in vehicles) {
      final fuel = await ref.read(rawFuelEntriesProvider(vehicle.id).future);
      final services =
          await ref.read(serviceEntriesProvider(vehicle.id).future);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsExportDone)),
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
    final locale = ref.watch(localeProvider);

    void save(Household updated) =>
        ref.read(settingsControllerProvider.notifier).save(updated);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      bottomNavigationBar: const GarageBottomNav(current: GarageTab.settings),
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          if (household != null) ...[
            _SectionTitle(l10n.settingsUnits),
            ListTile(
              title: Text(l10n.settingsDistance),
              trailing: DropdownButton<String>(
                value: household.distanceUnit,
                items: const [
                  DropdownMenuItem(value: 'km', child: Text('km')),
                  DropdownMenuItem(value: 'mi', child: Text('mi')),
                ],
                onChanged: (value) =>
                    save(_with(household, distanceUnit: value)),
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
                onChanged: (value) => save(_with(household, volumeUnit: value)),
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
                    save(_with(household, currencyCode: value)),
              ),
            ),
            const Divider(),
            _SectionTitle(l10n.settingsBundling),
            ListTile(
              title: Text(l10n.settingsBundlingWindowDays),
              trailing: _Stepper(
                value: household.bundlingWindowDays,
                step: 7,
                max: 365,
                onChanged: (value) =>
                    save(_with(household, bundlingWindowDays: value)),
              ),
            ),
            ListTile(
              title: Text(l10n.settingsBundlingWindowKm),
              trailing: _Stepper(
                value: household.bundlingWindowKm,
                step: 100,
                max: 100000,
                onChanged: (value) =>
                    save(_with(household, bundlingWindowKm: value)),
              ),
            ),
            const Divider(),
          ],
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
            leading: const Icon(Icons.download),
            title: Text(l10n.settingsExport),
            onTap: () => _export(context, ref),
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
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GarageTokens.space2),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
