import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../core/widgets/secondary_destinations.dart';
import '../../household/providers/household_providers.dart';

/// Everything the five tabs could not hold.
///
/// The bottom bar takes five and Material allows no more, so four features —
/// Statistics, the trip log, fuel stations, the calculator — and the garage
/// itself had to live somewhere else. "Somewhere else" was Settings, which is
/// the wrong word for any of them: nobody looks under Settings for the people
/// they share a car with, and for an app whose whole premise is shared upkeep,
/// that was the most consequential placement in it.
///
/// So the fifth tab is **More**, and Settings is one row inside it rather than
/// the door to everything. The tab did not change what it holds so much as
/// stop lying about it.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(currentHouseholdProvider).value;

    return GarageTabScaffold(
      current: GarageTab.more,
      title: l10n.settingsMore,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          // The features, first and named. The garage leads because it is the
          // one the product is about.
          for (final destination in secondaryDestinations(l10n))
            Card(
              child: ListTile(
                key: Key('more-${destination.route}'),
                leading: Icon(destination.icon),
                title: Text(destination.label),
                subtitle: destination.route == '/household' && household != null
                    ? Text(household.name)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(destination.route),
              ),
            ),
          const SizedBox(height: GarageTokens.space6),
          Text(
            l10n.settingsTitle.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          const SizedBox(height: GarageTokens.space2),
          Card(
            child: ListTile(
              key: const Key('more-settings'),
              leading: const Icon(Icons.tune),
              title: Text(l10n.settingsTitle),
              subtitle: Text(l10n.settingsPreferencesHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings'),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('more-data'),
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.settingsData),
              subtitle: Text(l10n.settingsDataHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/data'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.aboutTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/about'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.settingsPrivacyPolicy),
              trailing: const Icon(Icons.open_in_new),
              onTap: () =>
                  ref.read(urlOpenerProvider)(GarageLinks.privacyPolicy),
            ),
          ),
        ],
      ),
    );
  }
}
