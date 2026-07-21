import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// The app's primary sections. Shared so every top-level screen presents the
/// same four-tab bar and a consistent current-tab highlight.
enum GarageTab { dashboard, vehicles, planner, settings }

const _routes = {
  GarageTab.dashboard: '/',
  GarageTab.vehicles: '/vehicles',
  GarageTab.planner: '/planner',
  GarageTab.settings: '/settings',
};

class GarageBottomNav extends StatelessWidget {
  const GarageBottomNav({required this.current, super.key});

  final GarageTab current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NavigationBar(
      selectedIndex: GarageTab.values.indexOf(current),
      onDestinationSelected: (index) {
        final tab = GarageTab.values[index];
        if (tab != current) {
          context.go(_routes[tab]!);
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: l10n.dashboardTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.directions_car_outlined),
          selectedIcon: const Icon(Icons.directions_car),
          label: l10n.vehiclesTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.event_note_outlined),
          selectedIcon: const Icon(Icons.event_note),
          label: l10n.plannerTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settingsTitle,
        ),
      ],
    );
  }
}
