import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../features/household/providers/household_providers.dart';
import '../theme/garage_tokens.dart';
import 'secondary_destinations.dart';
import 'adaptive.dart';
import 'page_header.dart';

/// The app's primary sections. Shared so every top-level screen presents the
/// same four-tab navigation and a consistent current-tab highlight.
enum GarageTab { dashboard, timeline, vehicles, planner, more }

/// Where each tab lives. Public because the router has to agree with it: tabs
/// are peers and cross-fade between one another, and a tab route registered
/// like a pushed detail page instead slides in over its own navigation bar.
const tabRoutes = {
  GarageTab.dashboard: '/',
  GarageTab.timeline: '/timeline',
  GarageTab.vehicles: '/vehicles',
  GarageTab.planner: '/planner',
  GarageTab.more: '/more',
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
  // "More", not "Settings". Nobody looks under Settings for the people they
  // share a car with, and that is where the garage, the statistics, the trip
  // log, the stations and the calculator all lived.
  _Destination(
    GarageTab.more,
    Icons.more_horiz_outlined,
    Icons.more_horiz,
    l10n.settingsMore,
  ),
];

void _goTo(BuildContext context, GarageTab? current, int index) {
  final tab = GarageTab.values[index];
  if (tab != current) {
    context.go(tabRoutes[tab]!);
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
    this.title,
    this.actions = const [],
    this.floatingActionButton,
    this.contentWidth = ContentWidth.reading,
  });

  final GarageTab current;
  final Widget body;

  /// How much of a desktop window this screen's content should use. Reading
  /// width suits a form; a dashboard or a list wants the room.
  final ContentWidth contentWidth;

  /// The page's name. Given this, the scaffold titles the page itself: an app
  /// bar on a phone, a heading inside the content on a desktop window, where a
  /// top bar above a sidebar is phone chrome. Screens still passing [appBar]
  /// keep their old presentation on both.
  final String? title;

  /// Shown beside the title, in the app bar or the page header as appropriate.
  final List<Widget> actions;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  PreferredSizeWidget? _titleBar() =>
      title == null ? null : AppBar(title: Text(title!), actions: actions);

  @override
  Widget build(BuildContext context) {
    final wide = GarageBreakpoints.isWide(context);
    if (!wide) {
      return Scaffold(
        appBar: appBar ?? _titleBar(),
        body: body,
        bottomNavigationBar: GarageBottomNav(current: current),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: title == null ? appBar : null,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          GarageNavigationRail(current: current),
          const VerticalDivider(width: 1),
          Expanded(
            child: AdaptiveContent(
              width: contentWidth,
              // The page names itself inside the content here, rather than in
              // a bar above the sidebar.
              child: title == null
                  ? body
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PageHeader(title: title!, actions: actions),
                        Expanded(child: body),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sidebar, shared by the tab scaffold and by pushed pages.
///
/// A pushed page passes null: Statistics and the calculator are not tabs, and
/// highlighting one would claim the reader is somewhere they are not. They
/// still get the sidebar, because a window with room for it losing its
/// navigation is a phone's model on a desktop screen — the reader's only way
/// out was the browser's back button.
class GarageNavigationRail extends StatelessWidget {
  const GarageNavigationRail({required this.current, super.key});

  final GarageTab? current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // A labelled sidebar above the desktop breakpoint, a compact icon rail
    // between that and phone width. An icon strip beside a narrow column was
    // what made a 1400px window read as a phone app rather than a web app.
    final desktop = GarageBreakpoints.isDesktop(context);

    return NavigationRail(
      selectedIndex: current == null
          ? null
          : GarageTab.values.indexOf(current!),
      onDestinationSelected: (index) => _goTo(context, current, index),
      extended: desktop,
      minExtendedWidth: _sidebarWidth,
      labelType: desktop ? null : NavigationRailLabelType.all,
      leading: desktop ? const _SidebarHeader() : null,
      // Width a phone does not have is width to stop hiding things: these are
      // otherwise reachable only through Settings.
      trailing: desktop ? const _SidebarLinks() : null,
      destinations: [
        for (final destination in _destinations(l10n))
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
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

/// The sidebar's width when extended. The leading and trailing slots are laid
/// out with unbounded width, so anything put in them has to be constrained to
/// this or it fails to lay out at all.
const double _sidebarWidth = 240;

/// Which household you are looking at, at the top of the desktop sidebar.
///
/// Not the app's name: the dashboard destination is already called "Garage",
/// so a header repeating it would say the same word twice. The household is
/// the thing a phone has no room to show and a desktop does.
class _SidebarHeader extends ConsumerWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider).value;
    final households = ref.watch(myHouseholdsProvider).value ?? const [];
    final name = Text(
      household?.name ?? '',
      style: Theme.of(context).textTheme.titleLarge,
      overflow: TextOverflow.ellipsis,
    );

    return SizedBox(
      width: _sidebarWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GarageTokens.space4,
          GarageTokens.space4,
          GarageTokens.space4,
          GarageTokens.space6,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          // A menu only where there is something to choose. Belonging to one
          // garage is the ordinary case, and a dropdown arrow beside a name
          // that cannot change is a promise the app does not keep.
          child: households.length < 2
              ? name
              : PopupMenuButton<String>(
                  key: const Key('sidebar-garage-switcher'),
                  tooltip: AppLocalizations.of(context)!.householdSwitch,
                  position: PopupMenuPosition.under,
                  onSelected: (id) => ref
                      .read(householdControllerProvider.notifier)
                      .switchTo(id),
                  itemBuilder: (context) => [
                    for (final option in households)
                      PopupMenuItem(
                        value: option.id,
                        child: Row(
                          children: [
                            Icon(
                              option.id == household?.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                            ),
                            const SizedBox(width: GarageTokens.space3),
                            Flexible(child: Text(option.name)),
                          ],
                        ),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: name),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Secondary destinations in the sidebar, from the one list that also feeds
/// the "More" section in Settings — so a phone and a desktop offer the same
/// set rather than drifting apart, which is what happened before.
class _SidebarLinks extends StatelessWidget {
  const _SidebarLinks();

  @override
  Widget build(BuildContext context) {
    final links = secondaryDestinations(AppLocalizations.of(context)!);

    return SizedBox(
      width: _sidebarWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(
            indent: GarageTokens.space4,
            endIndent: GarageTokens.space4,
          ),
          for (final link in links)
            ListTile(
              dense: true,
              leading: Icon(link.icon, size: 20),
              title: Text(link.label),
              onTap: () => context.push(link.route),
            ),
        ],
      ),
    );
  }
}
