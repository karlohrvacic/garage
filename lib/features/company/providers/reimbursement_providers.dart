import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/company/money_entry.dart';
import '../../../domain/company/reimbursements.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'company_providers.dart';

/// Every money entry on the garage's cars, for the reimbursements and the
/// receipts check. Read per car, concurrently. Archived cars included: an
/// own-money fill-up on a car since sold is still owed to whoever paid it.
final fleetMoneyEntriesProvider = FutureProvider<List<MoneyEntry>>((ref) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  final perVehicle = await Future.wait([
    for (final vehicle in vehicles)
      Future(() async {
        final fuel = await ref.watch(rawFuelEntriesProvider(vehicle.id).future);
        final services = await ref.watch(
          serviceEntriesProvider(vehicle.id).future,
        );
        final costs = await ref.watch(costEntriesProvider(vehicle.id).future);
        return MoneyEntries.of(fuel: fuel, services: services, costs: costs);
      }),
  ]);
  return [for (final list in perVehicle) ...list];
});

/// Who is owed what, month by month.
final reimbursementsProvider = FutureProvider<List<ReimbursementLine>>((
  ref,
) async {
  final entries = await ref.watch(fleetMoneyEntriesProvider.future);
  final assignments = await ref.watch(fleetAssignmentsProvider.future);
  return Reimbursements.outstanding(entries: entries, assignments: assignments);
});
