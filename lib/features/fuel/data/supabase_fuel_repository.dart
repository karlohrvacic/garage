import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/stations/fuel_price_context.dart';
import 'fuel_repository.dart';

class SupabaseFuelRepository implements FuelRepository {
  SupabaseFuelRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('fuel_entries')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('odometer_km', ascending: true);
      return rows.map(fuelEntryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(FuelEntry entry) async {
    try {
      await _client.from('fuel_entries').insert({
        ...fuelEntryToRow(entry),
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(FuelEntry entry) async {
    try {
      await _client
          .from('fuel_entries')
          .update(fuelEntryToRow(entry))
          .eq('id', entry.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('fuel_entries').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The writable half of a `fuel_entries` row. `id` and `created_by` belong to
/// the server and are never sent from here.
Map<String, dynamic> fuelEntryToRow(FuelEntry entry) {
  return {
    'vehicle_id': entry.vehicleId,
    'entry_date': dateToColumn(entry.date),
    'odometer_km': entry.odometerKm,
    'volume_l': entry.volumeL,
    'price_per_l': entry.pricePerL,
    'total': entry.total,
    'full_tank': entry.fullTank,
    'missed_fill': entry.missedFill,
    'fuel_type_key': entry.fuelTypeKey,
    'station': entry.station,
    'notes': entry.notes,
    'cheapest_nearby_price': entry.priceContext?.pricePerUnit,
    'cheapest_nearby_km': entry.priceContext?.distanceKm,
    'cheapest_nearby_station': entry.priceContext?.station,
    'prices_seen_on': switch (entry.priceContext?.seenOn) {
      null => null,
      final seen => dateToColumn(seen),
    },
  };
}

FuelEntry fuelEntryFromRow(Map<String, dynamic> row) {
  return FuelEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    odometerKm: row['odometer_km'] as int,
    volumeL: (row['volume_l'] as num).toDouble(),
    pricePerL: (row['price_per_l'] as num?)?.toDouble(),
    total: (row['total'] as num?)?.toDouble(),
    fullTank: row['full_tank'] as bool,
    missedFill: row['missed_fill'] as bool,
    fuelTypeKey: row['fuel_type_key'] as String?,
    station: row['station'] as String?,
    notes: row['notes'] as String?,
    priceContext: switch ((
      row['cheapest_nearby_price'] as num?,
      row['cheapest_nearby_km'] as num?,
      row['cheapest_nearby_station'] as String?,
      row['prices_seen_on'] as String?,
    )) {
      (
        final num price,
        final num km,
        final String station,
        final String seen,
      ) =>
        FuelPriceContext(
          station: station,
          pricePerUnit: price.toDouble(),
          distanceKm: km.toDouble(),
          seenOn: dateFromColumn(seen),
        ),
      // A partial snapshot cannot happen — the table constrains all four to
      // arrive together — and a row from before the migration has none.
      _ => null,
    },
    createdBy: row['created_by'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
