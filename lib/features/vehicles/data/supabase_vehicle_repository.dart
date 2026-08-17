import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/entities/vehicle_transfer.dart';
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
  Future<void> delete(String id) async {
    try {
      await _client.from('vehicles').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> deleteAllForHousehold(String householdId) async {
    try {
      await _client.from('vehicles').delete().eq('household_id', householdId);
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

  @override
  Future<String> offerTransfer(String vehicleId) async {
    try {
      return await _client.rpc(
            'create_vehicle_transfer',
            params: {'target_vehicle': vehicleId},
          )
          as String;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async {
    try {
      final rows = await _client
          .from('vehicle_transfers')
          .select('id, vehicle_id, vehicle_nickname, redeemed_at')
          .eq('from_household_id', householdId)
          .order('created_at', ascending: false);
      return rows.map(vehicleTransferFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async {
    try {
      // Straight off the table rather than through a function: the select
      // policy already scopes it to the seller's own garage
      // (`0030_vehicle_transfer.sql:37`), and there is nothing to decide.
      final rows = await _client
          .from('vehicle_transfers')
          .select('code, expires_at')
          .eq('vehicle_id', vehicleId)
          .isFilter('redeemed_at', null)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1);
      return rows.isEmpty ? null : rows.first['code'] as String;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async {
    try {
      return await _client.rpc(
            'redeem_vehicle_transfer',
            params: {'transfer_code': code, 'target_household': householdId},
          )
          as String;
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
    'secondary_fuel_type_key': vehicle.secondaryFuelTypeKey,
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
    secondaryFuelTypeKey: row['secondary_fuel_type_key'] as String?,
    archived: row['archived'] as bool,
  );
}

VehicleTransfer vehicleTransferFromRow(Map<String, dynamic> row) {
  final redeemed = row['redeemed_at'] as String?;
  return VehicleTransfer(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    vehicleNickname: row['vehicle_nickname'] as String?,
    // Stored with a zone, unlike the date-only columns elsewhere, and read as
    // UTC for the same reason they are: the domain compares these.
    redeemedAt: redeemed == null ? null : DateTime.parse(redeemed).toUtc(),
  );
}
