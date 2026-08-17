import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/costs/providers/cost_providers.dart';
import '../../features/fuel/providers/fuel_providers.dart';
import '../../features/income/providers/income_providers.dart';
import '../../features/maintenance/providers/maintenance_providers.dart';
import '../../features/odometer/providers/odometer_providers.dart';
import '../../features/trips/providers/fleet_trip_providers.dart';
import '../../features/trips/providers/trip_providers.dart';
import '../../features/vehicles/providers/vehicle_providers.dart';
import '../supabase/supabase_client_provider.dart';

/// Keeps every device in a household in agreement.
///
/// Changes arrive as Postgres change events and simply invalidate the affected
/// providers rather than being merged into local state: refetching is cheap at
/// this data volume and cannot drift out of sync with what the server actually
/// holds. Last write wins, which is right for a household where two people
/// rarely edit the same row at the same second.
///
/// Invalidating the provider that holds a kind is enough for everything derived
/// from it — the odometer series, the projections, the statistics aggregate —
/// because Riverpod recomputes whatever watched it.
final realtimeSyncProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);

  /// One entry per table rather than a block each. The repetition was what
  /// made three entry kinds get added without anyone noticing this file, so
  /// the seventh is one line here.
  final perVehicleTables = <String, void Function(String vehicleId)>{
    'fuel_entries': (id) => ref.invalidate(rawFuelEntriesProvider(id)),
    'service_entries': (id) => ref.invalidate(serviceEntriesProvider(id)),
    'cost_entries': (id) => ref.invalidate(costEntriesProvider(id)),
    'odometer_entries': (id) => ref.invalidate(odometerEntriesProvider(id)),
    'trip_entries': (id) {
      ref
        ..invalidate(tripEntriesProvider(id))
        ..invalidate(allTripsProvider);
    },
    'income_entries': (id) => ref.invalidate(incomeEntriesProvider(id)),
    'reminder_rules': (id) => ref.invalidate(reminderRulesProvider(id)),
  };

  var channel = client
      .channel('household-changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'vehicles',
        callback: (_) => ref.invalidate(allVehiclesProvider),
      );
  for (final entry in perVehicleTables.entries) {
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: entry.key,
      callback: (payload) {
        final vehicleId = _vehicleIdFrom(payload);
        if (vehicleId != null) {
          entry.value(vehicleId);
        }
      },
    );
  }

  channel.subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});

/// The vehicle a change belongs to. A delete carries only the old row, so both
/// halves of the payload are consulted.
String? _vehicleIdFrom(PostgresChangePayload payload) {
  return (payload.newRecord['vehicle_id'] ?? payload.oldRecord['vehicle_id'])
      as String?;
}
