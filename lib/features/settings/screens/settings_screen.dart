import '../../../core/widgets/dialog_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/household.dart';
import '../../../domain/maintenance/tracking_level.dart';
import '../../auth/providers/auth_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../household/providers/member_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
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
    bool? settlementEnabled,
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
      settlementEnabled: settlementEnabled ?? base.settlementEnabled,
    );
  }

  /// Removes every vehicle in the household, and by cascade everything logged
  /// against them. The way back from a bad import, short of deleting the
  /// account itself.
  Future<void> _deleteAllData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null || !context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
        title: Text(l10n.settingsDeleteData),
        content: Text(l10n.settingsDeleteDataConfirm),
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
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .deleteAllForHousehold(household.id);
      ref
        ..invalidate(allVehiclesProvider)
        ..invalidate(vehiclesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsDeleteDataDone)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
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

  /// Changes the name the rest of the garage sees.
  Future<void> _renameSelf(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showTextPrompt(
      context,
      title: l10n.settingsYourName,
      label: l10n.settingsYourName,
      confirmLabel: l10n.commonSave,
      initialValue: current,
      fieldKey: const Key('your-name'),
    );
    if (name == null || name.isEmpty || name == current || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      // The name is rendered from three places — this device's own metadata,
      // the member list, and the map the timeline labels rows with — so all
      // three are refreshed rather than only the one on screen.
      ref
        ..invalidate(membersProvider)
        ..invalidate(memberNamesProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.settingsNameChanged)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(currentHouseholdProvider).value;
    final identity = ref.watch(accountIdentityProvider);
    final locale = ref.watch(localeProvider);
    final pushActive = ref.watch(pushRemindersActiveProvider);

    void save(Household Function(Household) patch) =>
        ref.read(settingsControllerProvider.notifier).save(patch);

    // A pushed page now, not a tab. The fifth tab is More, and Settings is one
    // row inside it: units and a theme picker were never the reason anybody
    // opened this, and making them the door to the garage, the statistics and
    // the trip log was the app's most consequential misplacement.
    return GaragePageScaffold(
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
                // Tappable, because the name was set once at sign-up and then
                // fixed forever — and it is not a private label: it is what
                // the rest of the garage sees against every entry you log.
                onTap: () => _renameSelf(context, ref, identity.name),
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
            _SectionTitle(
              l10n.settingsSettlement,
              note: l10n.settingsSettlementHint,
            ),
            SwitchListTile(
              key: const Key('settlement-enabled'),
              value: household.settlementEnabled,
              title: Text(l10n.settingsSettlementEnable),
              onChanged: (value) =>
                  save((base) => _with(base, settlementEnabled: value)),
            ),
            const Divider(),
            // Read-only, and there is nothing to toggle: whether reminders
            // reach the household or only this phone is decided by whether
            // the build has push configured. Saying which is in force closes
            // the gap where a member wondered why they never heard about a
            // reminder somebody else had set up.
            _SectionTitle(l10n.settingsReminders),
            ListTile(
              leading: Icon(
                pushActive
                    ? Icons.notifications_active_outlined
                    : Icons.phone_android_outlined,
                color: context.tokens.muted,
              ),
              title: Text(
                pushActive
                    ? l10n.settingsRemindersEveryone
                    : l10n.settingsRemindersThisDevice,
              ),
              subtitle: Text(
                pushActive
                    ? l10n.settingsRemindersEveryoneHint
                    : l10n.settingsRemindersThisDeviceHint,
              ),
            ),
            // When they arrive, in as many words. A reminder that turns up a
            // month before anything is due looks like a bug unless the app
            // has said that is the plan.
            ListTile(
              leading: Icon(
                Icons.schedule_outlined,
                color: context.tokens.muted,
              ),
              title: Text(l10n.settingsRemindersSchedule),
              subtitle: Text(
                pushActive
                    ? l10n.settingsRemindersScheduleServer
                    : l10n.settingsRemindersScheduleDevice,
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
          ListTile(
            leading: Icon(Icons.restart_alt, color: context.tokens.danger),
            title: Text(
              l10n.settingsDeleteData,
              style: TextStyle(color: context.tokens.danger),
            ),
            subtitle: Text(l10n.settingsDeleteDataHint),
            onTap: () => _deleteAllData(context, ref),
          ),
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
          tooltip: AppLocalizations.of(context)!.commonDecrease,
          icon: const Icon(Icons.remove),
          onPressed: value - step >= 0 ? () => onChanged(value - step) : null,
        ),
        Text('$value'),
        IconButton(
          tooltip: AppLocalizations.of(context)!.commonIncrease,
          icon: const Icon(Icons.add),
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}
