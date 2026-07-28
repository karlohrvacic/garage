import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'adaptive.dart';

/// The app's primary sections. Shared so every top-level screen presents the
/// same four-tab navigation and a consistent current-tab highlight.
enum GarageTab { dashboard, timeline, vehicles, planner, settings }

const _routes = {
  GarageTab.dashboard: '/',
  GarageTab.timeline: '/timeline',
  GarageTab.vehicles: '/vehicles',
  GarageTab.planner: '/planner',
  GarageTab.settings: '/settings',
};

class _Destination {
  const _Destination(this.tab, this.icon, this.selectedIcon, this.label);

  final GarageTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

List<_Destination> _destinations(AppLocalizations l10n) => [
  _Destination(
    GarageTab.dashboard,
    Icons.dashboard_outlined,
    Icons.dashboard,
    l10n.dashboardTitle,
  ),
  _Destination(
    GarageTab.timeline,
    Icons.view_timeline_outlined,
    Icons.view_timeline,
    l10n.timelineTitle,
  ),
  _Destination(
    GarageTab.vehicles,
    Icons.directions_car_outlined,
    Icons.directions_car,
    l10n.vehiclesTitle,
  ),
  _Destination(
    GarageTab.planner,
    Icons.event_note_outlined,
    Icons.event_note,
    l10n.plannerTitle,
  ),
  _Destination(
    GarageTab.settings,
    Icons.settings_outlined,
    Icons.settings,
    l10n.settingsTitle,
  ),
];

void _goTo(BuildContext context, GarageTab current, int index) {
  final tab = GarageTab.values[index];
  if (tab != current) {
    context.go(_routes[tab]!);
  }
}

/// Scaffold for the four top-level tab screens. Adapts the navigation to the
/// window: bottom bar on phones, left rail with a centered content column on
/// desktop-width windows.
class GarageTabScaffold extends StatelessWidget {
  const GarageTabScaffold({
    super.key,
    required this.current,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  final GarageTab current;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final wide = GarageBreakpoints.isWide(context);
    if (!wide) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: GarageBottomNav(current: current),
        floatingActionButton: floatingActionButton,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: GarageTab.values.indexOf(current),
            onDestinationSelected: (index) => _goTo(context, current, index),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final destination in _destinations(l10n))
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: AdaptiveContent(child: body)),
        ],
      ),
    );
  }
}

class GarageBottomNav extends StatelessWidget {
  const GarageBottomNav({required this.current, super.key});

  final GarageTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NavigationBar(
      selectedIndex: GarageTab.values.indexOf(current),
      onDestinationSelected: (index) => _goTo(context, current, index),
      destinations: [
        for (final destination in _destinations(l10n))
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }
}
