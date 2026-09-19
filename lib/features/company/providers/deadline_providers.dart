import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/company/fleet_deadlines.dart';
import '../../../domain/entities/vehicle_document.dart';
import '../../documents/providers/document_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// Every car's deadlines, soonest first: what the projection puts on the
/// calendar, and the papers' expiry dates.
final fleetDeadlinesProvider = FutureProvider<List<FleetDeadline>>((ref) async {
  final projections = await ref.watch(householdProjectionsProvider.future);
  final vehicles = await ref.watch(vehiclesProvider.future);
  // Read concurrently; wall-clock is the slowest car rather than the sum.
  final papers = await Future.wait([
    for (final vehicle in vehicles)
      ref.watch(vehicleDocumentsProvider(vehicle.id).future),
  ]);
  final documents = <String, List<VehicleDocument>>{
    for (var i = 0; i < vehicles.length; i++) vehicles[i].id: papers[i],
  };
  return FleetDeadlines.of(
    projections: projections,
    documentsByVehicle: documents,
    today: ref.watch(todayProvider),
  );
});
