import '../../../core/format/unit_format.dart';
import '../providers/unit_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../stations/providers/station_providers.dart';
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
import '../../../core/widgets/confirm_delete.dart';

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
    final confirmed = await confirmDestructive(
      context,
      title: l10n.settingsDeleteData,
      body: l10n.settingsDeleteDataConfirm,
      confirmLabel: l10n.settingsDeleteConfirmAction,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .deleteAllForHousehold(household.id);
      ref.invalidate(garageBootstrapProvider);
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
    // The name, typed. This is the one action with no recovery at all, and
    // it asked for a single tap on a button the app uses for every save.
    final household = await ref.read(currentHouseholdProvider.future);
    if (!context.mounted) {
      return;
    }
    if (household == null) {
      // Failing closed: null covers a failed read as well as a user with no
      // garage, and this is the one act with no way back.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      return;
    }
    {
      final typed = await showTextPrompt(
        context,
        title: l10n.settingsDeleteConfirmTitle,
        label: l10n.settingsDeleteTypeName,
        confirmLabel: l10n.settingsDeleteConfirmAction,
        // In the dialog, not after it: answered with a snackbar over a
        // dismissed prompt, a typo meant opening it and typing again.
        validator: (value) =>
            value == household.name ? null : l10n.settingsDeleteNameMismatch,
      );
      if (typed == null || !context.mounted) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: l10n.settingsDeleteConfirmTitle,
      body: l10n.settingsDeleteConfirmBody,
      confirmLabel: l10n.settingsDeleteConfirmAction,
    );
    if (confirmed) {
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
          // Language and theme first: a Croatian household's first job in
          // Settings used to be scrolling past seven sections to find them.
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
                // Each language names itself. Somebody who has the app in a
                // language they cannot read is looking for the word they do
                // know, not for its English name.
                const RadioListTile<String>(
                  value: 'it',
                  title: Text('Italiano'),
                ),
              ],
            ),
          ),
          const Divider(),
          const SizedBox(height: GarageTokens.space2),
          if (household != null) ...[
            _SectionTitle(l10n.settingsUnits, note: l10n.settingsUnitsHint),
            ListTile(
              title: Text(l10n.settingsDistance),
              trailing: DropdownButton<String>(
                underline: const SizedBox.shrink(),
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
                underline: const SizedBox.shrink(),
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
              // Capped and expanded, unlike the two unit rows above it: those
              // hold "km" and "l", while a currency reads "€ · EUR" and at a
              // large font in a long language it pushed the row past the edge
              // of a narrow phone.
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  value: _currencies.contains(household.currencyCode)
                      ? household.currencyCode
                      : null,
                  items: [
                    for (final code in _currencies)
                      DropdownMenuItem(
                        value: code,
                        // Bare ISO codes made "ALL" read as the word: the
                        // symbol is what a person recognises. Where a
                        // currency writes itself as its code, the code alone
                        // is the symbol, and "CHF · CHF" is just noise.
                        child: Text(
                          _currencySymbol(code) == code
                              ? code
                              : '$code · ${_currencySymbol(code)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      save((base) => _with(base, currencyCode: value)),
                ),
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
              trailing: _DistanceStepper(
                km: household.bundlingWindowKm,
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
            _SectionTitle(l10n.settingsFillUps),
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
                  // Not `enabled: false` once it is on. A disabled ListTile
                  // greys its title and subtitle, so the row said "On" in the
                  // colour the rest of the app uses for "unavailable", next to a
                  // tick — three signals, two of them contradicting each other.
                  // Nothing left to do is not the same as nothing you may do.
                  onTap: (granted.value ?? false)
                      ? null
                      : () => _enablePumpAutofill(context, ref),
                );
              },
            ),
            const SizedBox(height: GarageTokens.space4),
            // Read-only, and there is nothing to toggle: whether reminders
            // reach the household or only this phone is decided by whether
            // the build has push configured. Saying which is in force closes
            // the gap where a member wondered why they never heard about a
            // reminder somebody else had set up.
            _SectionTitle(l10n.settingsReminders),
            // Prose, not rows. Three read-only lines styled exactly like the
            // dropdowns and switches above them read as settings whose
            // control had failed to load.
            _ReadOnlyNote(
              icon: pushActive
                  ? Icons.notifications_active_outlined
                  : Icons.phone_android_outlined,
              title: pushActive
                  ? l10n.settingsRemindersEveryone
                  : l10n.settingsRemindersThisDevice,
              body: pushActive
                  ? l10n.settingsRemindersEveryoneHint
                  : l10n.settingsRemindersThisDeviceHint,
            ),
            // When they arrive, in as many words. A reminder that turns up a
            // month before anything is due looks like a bug unless the app
            // has said that is the plan.
            _ReadOnlyNote(
              icon: Icons.schedule_outlined,
              title: l10n.settingsRemindersSchedule,
              body: pushActive
                  ? l10n.settingsRemindersScheduleServer
                  : l10n.settingsRemindersScheduleDevice,
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
          ],
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

/// The bundling window, stepped and shown in whatever distance unit the
/// household reads while staying kilometres in storage.
///
/// The plain [_Stepper] renders a bare number, which is right where the label
/// names the unit ("within (days)") and wrong where it deliberately does not
/// ("within (distance)"). A household reading miles saw `500` and was setting
/// five hundred kilometres, with nothing on screen that could have said so.
///
/// Stepping happens in the displayed unit rather than in storage: a hundred
/// kilometres under a miles reader walks 311, 373, 435 — arithmetic nobody
/// asked for. The round-trip through [UnitPreferences] can move the stored
/// value by a kilometre or so, which does not matter for a grouping window
/// measured in hundreds.
class _DistanceStepper extends ConsumerWidget {
  const _DistanceStepper({required this.km, required this.onChanged});

  final int km;

  /// Called with kilometres, whatever is on screen.
  final ValueChanged<int> onChanged;

  /// A hundred of whichever unit is shown.
  static const _step = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: preferences,
    );
    final shown = preferences.kmToDisplay(km.toDouble()).round();

    void moveTo(int display) =>
        onChanged(preferences.displayToKm(display.toDouble()).round());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.commonDecrease,
          icon: const Icon(Icons.remove),
          onPressed: shown - _step >= 0 ? () => moveTo(shown - _step) : null,
        ),
        Text(format.formatDistance(km.toDouble(), decimals: 0)),
        IconButton(
          tooltip: l10n.commonIncrease,
          icon: const Icon(Icons.add),
          onPressed: () => moveTo(shown + _step),
        ),
      ],
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

/// The symbol a household would recognise beside its ISO code. Not
/// exhaustive: a code with no symbol here shows its own letters, which is
/// what a bare list did for all of them.
String _currencySymbol(String code) {
  return switch (code) {
    'EUR' => '€',
    'GBP' => '£',
    'CHF' => 'CHF',
    'BAM' => 'KM',
    'RSD' => 'дин.',
    'MKD' => 'ден',
    'ALL' => 'L',
    'PLN' => 'zł',
    'CZK' => 'Kč',
    'HUF' => 'Ft',
    'RON' => 'lei',
    'BGN' => 'лв',
    'SEK' || 'NOK' || 'DKK' => 'kr',
    'USD' => r'$',
    _ => code,
  };
}

/// A line of explanation in Settings, styled as prose rather than as a row
/// with a missing control.
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space1,
        GarageTokens.space4,
        GarageTokens.space3,
      ),
      // One stop for a screen reader, as the list tile it replaced was: the
      // explanation is stranded if it is read apart from its heading.
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: context.tokens.muted),
            ),
            const SizedBox(width: GarageTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.tokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
