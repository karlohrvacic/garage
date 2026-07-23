import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../../domain/entities/vehicle.dart';
import '../providers/vehicle_providers.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vehiclesTitle)),
      bottomNavigationBar: const GarageBottomNav(current: GarageTab.vehicles),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicles/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.vehiclesAdd),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(GarageTokens.space4),
            child: TextField(
              decoration: InputDecoration(
                labelText: l10n.vehicleSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Vehicle>>(
              value: vehicles,
              onRetry: () => ref.invalidate(allVehiclesProvider),
              empty: () => EmptyState(
                message: l10n.vehiclesEmpty,
                action: FilledButton(
                  onPressed: () => context.push('/vehicles/new'),
                  child: Text(l10n.vehiclesAdd),
                ),
              ),
              data: (list) {
                final filtered = list
                    .where(
                      (v) => [v.nickname, v.make, v.model, v.plate]
                          .whereType<String>()
                          .any((f) => f.toLowerCase().contains(_query)),
                    )
                    .toList(growable: false);
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GarageTokens.space4,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: GarageTokens.space2),
                  itemBuilder: (context, index) {
                    final vehicle = filtered[index];
                    return Card(
                      child: ListTile(
                        title: Text(vehicle.nickname),
                        subtitle: Text(
                          [vehicle.make, vehicle.model, vehicle.year?.toString()]
                              .whereType<String>()
                              .join(' · '),
                        ),
                        trailing: vehicle.plate == null
                            ? null
                            : Text(
                                vehicle.plate!,
                                style: GarageTheme.numeric(
                                  Theme.of(context).textTheme.labelMedium!,
                                ),
                              ),
                        onTap: () => context.push('/vehicles/${vehicle.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
