import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
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
      return rows.map(_toVehicle).toList(growable: false);
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
            ..._toRow(vehicle),
            'created_by': _client.auth.currentUser!.id,
          })
          .select()
          .single();
      return _toVehicle(row);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(Vehicle vehicle) async {
    try {
      await _client.from('vehicles').update(_toRow(vehicle)).eq('id', vehicle.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    try {
      await _client.from('vehicles').update({'archived': archived}).eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Map<String, dynamic> _toRow(Vehicle vehicle) {
    return {
      'household_id': vehicle.householdId,
      'nickname': vehicle.nickname,
      'fuel_type_key': vehicle.fuelTypeKey,
      'baseline_odometer_km': vehicle.baselineOdometerKm,
      'baseline_date': _dateToColumn(vehicle.baselineDate),
      'make': vehicle.make,
      'model': vehicle.model,
      'year': vehicle.year,
      'trim': vehicle.trim,
      'vin': vehicle.vin,
      'plate': vehicle.plate,
      'photo_path': vehicle.photoUrl,
      'archived': vehicle.archived,
    };
  }

  Vehicle _toVehicle(Map<String, dynamic> row) {
    return Vehicle(
      id: row['id'] as String,
      householdId: row['household_id'] as String,
      nickname: row['nickname'] as String,
      fuelTypeKey: row['fuel_type_key'] as String,
      baselineOdometerKm: row['baseline_odometer_km'] as int,
      baselineDate: _dateFromColumn(row['baseline_date'] as String),
      make: row['make'] as String?,
      model: row['model'] as String?,
      year: row['year'] as int?,
      trim: row['trim'] as String?,
      vin: row['vin'] as String?,
      plate: row['plate'] as String?,
      photoUrl: row['photo_path'] as String?,
      archived: row['archived'] as bool,
    );
  }
}

/// A Postgres `date` column carries no time or zone. The domain treats every
/// [DateTime] as UTC (its `isUtc` flag is load-bearing for equality), so a
/// date-only value is read as UTC midnight of that calendar day rather than
/// `DateTime.parse`'s local midnight, which would flip the flag and silently
/// break entity equality on round-trip.
String _dateToColumn(DateTime date) =>
    date.toUtc().toIso8601String().split('T').first;

DateTime _dateFromColumn(String value) => DateTime.parse('${value}T00:00:00Z');
