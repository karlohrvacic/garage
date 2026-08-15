import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/tyre_set.dart';
import 'tyre_repository.dart';

class SupabaseTyreRepository implements TyreRepository {
  SupabaseTyreRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TyreSet>> forVehicle(String vehicleId) async {
    try {
      // The readings come along with the set: a set is only useful with its
      // series, and a second round trip per set would be worse.
      final rows = await _client
          .from('tyre_sets')
          .select('*, tyre_readings(*)')
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: true);
      return rows.map(tyreSetFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> addSet({
    required String vehicleId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
  }) async {
    try {
      await _client.from('tyre_sets').insert({
        ...tyreSetToRow(
          vehicleId: vehicleId,
          name: name,
          season: season,
          size: size,
          storageLocation: storageLocation,
        ),
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> fitSet({
    required String vehicleId,
    required String setId,
  }) async {
    try {
      // Take the old set off first: only one set per vehicle may be fitted,
      // and the unique index would refuse the pair in the other order.
      await _client
          .from('tyre_sets')
          .update({'fitted': false})
          .eq('vehicle_id', vehicleId)
          .eq('fitted', true);
      await _client
          .from('tyre_sets')
          .update({'fitted': true, 'fitted_at': dateToColumn(DateTime.now())})
          .eq('id', setId);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> retireSet(String setId) async {
    try {
      await _client
          .from('tyre_sets')
          .update({'retired_at': dateToColumn(DateTime.now()), 'fitted': false})
          .eq('id', setId);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> deleteSet(String setId) async {
    try {
      await _client.from('tyre_sets').delete().eq('id', setId);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> addReading({
    required String tyreSetId,
    required DateTime date,
    int? odometerKm,
    double? frontLeftMm,
    double? frontRightMm,
    double? rearLeftMm,
    double? rearRightMm,
  }) async {
    try {
      await _client.from('tyre_readings').insert({
        ...tyreReadingToRow(
          tyreSetId: tyreSetId,
          date: date,
          odometerKm: odometerKm,
          frontLeftMm: frontLeftMm,
          frontRightMm: frontRightMm,
          rearLeftMm: rearLeftMm,
          rearRightMm: rearRightMm,
        ),
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

Map<String, dynamic> tyreSetToRow({
  required String vehicleId,
  required String name,
  required TyreSeason season,
  String? size,
  String? storageLocation,
}) {
  return {
    'vehicle_id': vehicleId,
    'name': name,
    'season': season.key,
    'size': size,
    'storage_location': storageLocation,
  };
}

Map<String, dynamic> tyreReadingToRow({
  required String tyreSetId,
  required DateTime date,
  int? odometerKm,
  double? frontLeftMm,
  double? frontRightMm,
  double? rearLeftMm,
  double? rearRightMm,
}) {
  return {
    'tyre_set_id': tyreSetId,
    'reading_date': dateToColumn(date),
    'odometer_km': odometerKm,
    'front_left_mm': frontLeftMm,
    'front_right_mm': frontRightMm,
    'rear_left_mm': rearLeftMm,
    'rear_right_mm': rearRightMm,
  };
}

TyreSet tyreSetFromRow(Map<String, dynamic> row) {
  final readings = (row['tyre_readings'] as List<dynamic>?) ?? const [];
  return TyreSet(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    name: row['name'] as String,
    season: TyreSeason.fromKey(row['season'] as String),
    fitted: row['fitted'] as bool,
    size: row['size'] as String?,
    storageLocation: row['storage_location'] as String?,
    fittedAt: row['fitted_at'] == null
        ? null
        : dateFromColumn(row['fitted_at'] as String),
    retiredAt: row['retired_at'] == null
        ? null
        : dateFromColumn(row['retired_at'] as String),
    createdBy: row['created_by'] as String,
    readings: [
      for (final reading in readings.cast<Map<String, dynamic>>())
        tyreReadingFromRow(reading),
    ],
  );
}

TyreReading tyreReadingFromRow(Map<String, dynamic> row) {
  double? mm(Object? value) => (value as num?)?.toDouble();

  return TyreReading(
    id: row['id'] as String,
    date: dateFromColumn(row['reading_date'] as String),
    odometerKm: (row['odometer_km'] as num?)?.toInt(),
    frontLeftMm: mm(row['front_left_mm']),
    frontRightMm: mm(row['front_right_mm']),
    rearLeftMm: mm(row['rear_left_mm']),
    rearRightMm: mm(row['rear_right_mm']),
  );
}
