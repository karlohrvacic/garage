import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/sync/realtime_sync.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/bundle_card.dart';
import '../widgets/household_metrics_strip.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Holds the realtime subscription open for as long as the dashboard — the
    // app's landing screen — is mounted, so a household's devices stay in sync.
    ref.watch(realtimeSyncProvider);

    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );

    final topBundle = ref.watch(topBundleProvider).value;
    final projections =
        ref.watch(householdProjectionsProvider).value ?? const [];
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final vehicleNames = {for (final v in vehicles) v.id: v.nickname};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      bottomNavigationBar: const GarageBottomNav(current: GarageTab.dashboard),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allVehiclesProvider);
          ref.invalidate(householdProjectionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: GarageTokens.space8),
          children: [
            const HouseholdMetricsStrip(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: GarageTokens.space4,
              ),
              child: topBundle == null
                  ? _NoBundles(message: l10n.dashboardNoBundles)
                  : BundleCard(bundle: topBundle, vehicleNames: vehicleNames),
            ),
            if (projections.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GarageTokens.space4,
                  GarageTokens.space4,
                  GarageTokens.space4,
                  GarageTokens.space2,
                ),
                child: Text(
                  l10n.dashboardDueSoonest,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final projection in projections.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarageTokens.space4,
                    vertical: GarageTokens.space1,
                  ),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        serviceTypeLabel(l10n, projection.serviceTypeKey),
                      ),
                      subtitle: Text(
                        '${vehicleNames[projection.vehicleId] ?? ''} · '
                        '${format.formatDate(projection.projectedDueDate)}',
                      ),
                      onTap: () => context.go(
                        '/vehicles/${projection.vehicleId}/maintenance',
                      ),
                    ),
                  ),
                ),
            ],
            for (final vehicle in vehicles)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarageTokens.space4,
                  vertical: GarageTokens.space1,
                ),
                child: Card(
                  child: ListTile(
                    title: Text(vehicle.nickname),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.local_gas_station),
                          onPressed: () =>
                              context.go('/vehicles/${vehicle.id}/fuel'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.build_outlined),
                          onPressed: () =>
                              context.go('/vehicles/${vehicle.id}/maintenance'),
                        ),
                      ],
                    ),
                    onTap: () => context.go('/vehicles/${vehicle.id}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoBundles extends StatelessWidget {
  const _NoBundles({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Text(
          message,
          style: TextStyle(color: context.tokens.muted),
        ),
      ),
    );
  }
}
