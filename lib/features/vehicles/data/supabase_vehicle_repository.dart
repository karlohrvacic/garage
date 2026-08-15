import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/vehicle.dart';
import 'vehicle_repository.dart';

class SupabaseVehicleRepository implements VehicleRepository {
  SupabaseVehicleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async {
    try {
      final rows = await _client
          .from('vehicles')
          .select()
          .eq('household_id', householdId);
      return rows.map(vehicleFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    try {
      final row = await _client
          .from('vehicles')
          .insert({
            ...vehicleToRow(vehicle),
            'created_by': _client.auth.currentUser!.id,
          })
          .select()
          .single();
      return vehicleFromRow(row);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(Vehicle vehicle) async {
    try {
      await _client
          .from('vehicles')
          .update(vehicleToRow(vehicle))
          .eq('id', vehicle.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _client
          .from('vehicles')
          .update({'archived': archived})
          .eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The writable half of a `vehicles` row; `id` is the server's.
Map<String, dynamic> vehicleToRow(Vehicle vehicle) {
  return {
    'household_id': vehicle.householdId,
    'nickname': vehicle.nickname,
    'fuel_type_key': vehicle.fuelTypeKey,
    'baseline_odometer_km': vehicle.baselineOdometerKm,
    'baseline_date': dateToColumn(vehicle.baselineDate),
    'make': vehicle.make,
    'model': vehicle.model,
    'year': vehicle.year,
    'trim': vehicle.trim,
    'vin': vehicle.vin,
    'plate': vehicle.plate,
    'photo_path': vehicle.photoUrl,
    'tank_capacity_l': vehicle.tankCapacityL,
    'archived': vehicle.archived,
  };
}

Vehicle vehicleFromRow(Map<String, dynamic> row) {
  return Vehicle(
    id: row['id'] as String,
    householdId: row['household_id'] as String,
    nickname: row['nickname'] as String,
    fuelTypeKey: row['fuel_type_key'] as String,
    baselineOdometerKm: row['baseline_odometer_km'] as int,
    baselineDate: dateFromColumn(row['baseline_date'] as String),
    make: row['make'] as String?,
    model: row['model'] as String?,
    year: row['year'] as int?,
    trim: row['trim'] as String?,
    vin: row['vin'] as String?,
    plate: row['plate'] as String?,
    photoUrl: row['photo_path'] as String?,
    tankCapacityL: (row['tank_capacity_l'] as num?)?.toDouble(),
    archived: row['archived'] as bool,
  );
}
