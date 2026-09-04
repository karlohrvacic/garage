import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../../core/supabase/supabase_client_provider.dart';

/// One page that says what the app can do, and opens each thing it names.
///
/// The getting-started card says how a vehicle gets in. Nothing said what
/// happens after: someone who never tapped "More" had no way to learn that
/// the planner, the stations or the calculator exist. This is a list, not a
/// walkthrough — every row is a real entry point rather than a description of
/// one, and there is no state to dismiss, so it is as useful on the tenth
/// day as on the first.
class FeaturesScreen extends ConsumerWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // With one car in the garage, "where it lives" can be the actual place.
    // Null while it loads, and on the signed-out tour, where the list is
    // nobody's yet.
    final vehicles = ref.watch(vehiclesProvider).value;
    final onlyVehicle = vehicles != null && vehicles.length == 1
        ? vehicles.single
        : null;
    final features = [
      _Feature(
        icon: Icons.directions_car_outlined,
        title: l10n.featureAddVehicle,
        blurb: l10n.featureAddVehicleBlurb,
        route: '/vehicles/new',
      ),
      _Feature(
        icon: Icons.local_gas_station_outlined,
        title: l10n.featureFuel,
        blurb: l10n.featureFuelBlurb,
        route: '/',
        tab: true,
      ),
      _Feature(
        icon: Icons.event_available_outlined,
        title: l10n.plannerTitle,
        blurb: l10n.featurePlannerBlurb,
        route: '/planner',
        tab: true,
      ),
      _Feature(
        icon: Icons.history_outlined,
        title: l10n.timelineTitle,
        blurb: l10n.featureTimelineBlurb,
        route: '/timeline',
        tab: true,
      ),
      _Feature(
        id: 'receipts',
        icon: Icons.receipt_long_outlined,
        title: l10n.featureReceipts,
        blurb: l10n.featureReceiptsBlurb,
        route: '/timeline',
        tab: true,
      ),
      _Feature(
        icon: Icons.insights_outlined,
        title: l10n.statsTitle,
        blurb: l10n.featureStatsBlurb,
        route: '/stats',
      ),
      _Feature(
        icon: Icons.local_offer_outlined,
        title: l10n.stationsTitle,
        blurb: l10n.featureStationsBlurb,
        route: '/stations',
      ),
      _Feature(
        icon: Icons.route_outlined,
        title: l10n.tripsTitle,
        blurb: l10n.featureTripsBlurb,
        route: '/trips',
      ),
      _Feature(
        icon: Icons.calculate_outlined,
        title: l10n.calculatorTitle,
        blurb: l10n.featureCalculatorBlurb,
        route: '/calculator',
      ),
      _Feature(
        icon: Icons.tire_repair_outlined,
        title: l10n.featureTyres,
        blurb: l10n.featureTyresBlurb,
        // The blurb says "on each vehicle's page" and the row landed on the
        // vehicle list, which is where somebody hunting for their winter set
        // had already looked. With one car there is no list to pick from, so
        // this goes the whole way.
        route: onlyVehicle == null
            ? '/vehicles'
            : '/vehicles/${onlyVehicle.id}/tyres',
        tab: onlyVehicle == null,
        id: 'tyres',
      ),
      _Feature(
        icon: Icons.people_outline,
        title: l10n.featureShare,
        blurb: l10n.featureShareBlurb,
        route: '/household',
      ),
      _Feature(
        icon: Icons.cloud_sync_outlined,
        title: l10n.featureData,
        blurb: l10n.featureDataBlurb,
        route: '/data',
      ),
      _Feature(
        icon: Icons.code_outlined,
        title: l10n.apiTitle,
        blurb: l10n.featureApiBlurb,
        route: '/api',
      ),
    ];

    final signedIn = ref.watch(currentUserIdProvider) != null;

    return GaragePageScaffold(
      title: l10n.featuresTitle,
      // Read before signing up as well as after. Every rail destination would
      // bounce a visitor to the sign-in form, so on that reading it is not
      // offered.
      showNavigation: signedIn,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text(
            l10n.featuresHint,
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: GarageTokens.space3),
          for (final feature in features)
            Card(
              child: ListTile(
                key: Key('feature-${feature.id}'),
                leading: Icon(feature.icon, color: context.tokens.accent),
                title: Text(feature.title),
                subtitle: Text(feature.blurb),
                trailing: const Icon(Icons.chevron_right),
                // A tab is switched to, not pushed: pushing the dashboard on
                // top of More would leave a back arrow that goes nowhere
                // useful.
                onTap: () => feature.tab
                    ? context.go(feature.route)
                    : context.push(feature.route),
              ),
            ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.blurb,
    required this.route,
    this.tab = false,
    String? id,
  }) : id = id ?? route;

  /// What the row is for, when two rows open the same place.
  final String id;
  final IconData icon;
  final String title;
  final String blurb;
  final String route;

  /// Whether [route] is one of the five tabs.
  final bool tab;
}
