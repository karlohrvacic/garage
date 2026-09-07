import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

/// A destination that is not one of the five tabs.
class SecondaryDestination {
  const SecondaryDestination({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

/// The features that are not tabs, in one list.
///
/// The bottom bar holds five and Material allows no more, so these five had to
/// live somewhere else — and where they lived depended on the window. A
/// desktop sidebar listed them; a phone did not, so **Statistics, the trip log,
/// fuel stations and the calculator each had exactly one way in**: an
/// unlabelled icon on the dashboard, or in the trip log's case a timeline row
/// that only exists once a trip has already been logged. A feature you can
/// only reach after using it is not reachable.
///
/// One list rather than two, because the two had already drifted: the sidebar's
/// own comment said "on a phone these live under Settings", and only the
/// garage did.
List<SecondaryDestination> secondaryDestinations(AppLocalizations l10n) {
  return [
    SecondaryDestination(
      label: l10n.householdTitle,
      icon: Icons.people_outline,
      route: '/household',
    ),
    SecondaryDestination(
      label: l10n.statsTitle,
      icon: Icons.insights_outlined,
      route: '/stats',
    ),
    SecondaryDestination(
      label: l10n.tripsTitle,
      icon: Icons.route_outlined,
      route: '/trips',
    ),
    // Its only other way in is an unlabelled icon in the trip log's toolbar,
    // which is precisely the shape this list exists to correct. It is worth
    // opening before a single route has been named, too: the empty state is
    // what explains how one gets named.
    SecondaryDestination(
      label: l10n.routeTrendsTitle,
      icon: Icons.timeline_outlined,
      route: '/routes',
    ),
    // A car somebody lent you is not a car in your garage, so it does not
    // appear in Vehicles until the code has been used.
    SecondaryDestination(
      label: l10n.stationsTitle,
      icon: Icons.local_gas_station_outlined,
      route: '/stations',
    ),
    SecondaryDestination(
      label: l10n.calculatorTitle,
      icon: Icons.calculate_outlined,
      route: '/calculator',
    ),
  ];
}

/// What the More page holds besides the secondary destinations: the tour,
/// Settings, Your data and About. On a desktop window these sit in the
/// sidebar too, and "More" itself is no longer a destination there: a
/// sidebar with room for every link has nothing to fold.
List<SecondaryDestination> settingsDestinations(AppLocalizations l10n) {
  return [
    SecondaryDestination(
      label: l10n.featuresTitle,
      icon: Icons.explore_outlined,
      route: '/tour',
    ),
    SecondaryDestination(
      label: l10n.settingsTitle,
      icon: Icons.tune,
      route: '/settings',
    ),
    SecondaryDestination(
      label: l10n.settingsData,
      icon: Icons.save_alt,
      route: '/data',
    ),
    SecondaryDestination(
      label: l10n.aboutTitle,
      icon: Icons.info_outline,
      route: '/about',
    ),
  ];
}
