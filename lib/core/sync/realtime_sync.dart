import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/fuel/providers/fuel_providers.dart';
import '../../features/maintenance/providers/maintenance_providers.dart';
import '../../features/vehicles/providers/vehicle_providers.dart';
import '../supabase/supabase_client_provider.dart';

/// Keeps every device in a household in agreement.
///
/// Changes arrive as Postgres change events and simply invalidate the affected
/// providers rather than being merged into local state: refetching is cheap at
/// this data volume and cannot drift out of sync with what the server actually
/// holds. Last write wins, which is right for a household where two people
/// rarely edit the same row at the same second.
final realtimeSyncProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);

  final channel = client.channel('household-changes')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'vehicles',
      callback: (_) => ref.invalidate(allVehiclesProvider),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'fuel_entries',
      callback: (payload) {
        final vehicleId = _vehicleIdFrom(payload);
        if (vehicleId != null) {
          ref.invalidate(rawFuelEntriesProvider(vehicleId));
        }
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'service_entries',
      callback: (payload) {
        final vehicleId = _vehicleIdFrom(payload);
        if (vehicleId != null) {
          ref.invalidate(serviceEntriesProvider(vehicleId));
        }
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'reminder_rules',
      callback: (payload) {
        final vehicleId = _vehicleIdFrom(payload);
        if (vehicleId != null) {
          ref.invalidate(reminderRulesProvider(vehicleId));
        }
      },
    );

  channel.subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});

String? _vehicleIdFrom(PostgresChangePayload payload) {
  final record =
      payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
  return record['vehicle_id'] as String?;
}
