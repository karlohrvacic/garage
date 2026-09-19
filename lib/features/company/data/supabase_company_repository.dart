import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/entities/vehicle_assignment.dart';
import 'company_repository.dart';

class SupabaseCompanyRepository implements CompanyRepository {
  SupabaseCompanyRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<VehicleAssignment>> assignmentsForVehicles(
    List<String> vehicleIds,
  ) async {
    if (vehicleIds.isEmpty) {
      return const [];
    }
    try {
      // Sorted, so the console's one query keys the same copy whatever order
      // the garage listed its cars in this time.
      final rows = await _cache.rows(
        'assignments/${([...vehicleIds]..sort()).join(',')}',
        () => _client
            .from('vehicle_assignments')
            .select()
            .inFilter('vehicle_id', vehicleIds)
            .order('from_date', ascending: false)
            .retry(enabled: false),
      );
      return rows.map(vehicleAssignmentFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<VehicleAssignment>> mine() async {
    try {
      final rows = await _cache.rows(
        'assignments/mine',
        () => _client
            .from('vehicle_assignments')
            .select()
            .eq('user_id', _client.auth.currentUser!.id)
            .order('from_date', ascending: false)
            .retry(enabled: false),
      );
      return rows.map(vehicleAssignmentFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String?> handOver({
    required String vehicleId,
    required DateTime on,
    int? odometerKm,
    String? toUserId,
    String? note,
  }) async {
    try {
      return await _client.rpc<String?>(
        'hand_over_vehicle',
        params: {
          'target_vehicle': vehicleId,
          'on_date': dateToColumn(on),
          'odometer_km': odometerKm,
          'to_user': toUserId,
          'handover_note': note,
        },
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> confirm(String assignmentId) async {
    try {
      await _client.rpc(
        'confirm_vehicle_assignment',
        params: {'assignment_id': assignmentId},
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> deleteAssignment(String id) async {
    try {
      await _client.from('vehicle_assignments').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> markReimbursed({
    required String table,
    required List<String> ids,
    required DateTime at,
  }) async {
    try {
      await _client
          .from(table)
          .update({'reimbursed_at': at.toUtc().toIso8601String()})
          .inFilter('id', ids);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> requestReceiptReminder({
    required String vehicleId,
    required String kind,
    required String entryId,
    required String driverId,
  }) async {
    try {
      await _client.rpc(
        'request_receipt_reminder',
        params: {
          'target_vehicle': vehicleId,
          'kind': kind,
          'entry': entryId,
          'driver': driverId,
        },
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

VehicleAssignment vehicleAssignmentFromRow(Map<String, dynamic> row) {
  DateTime? stamp(String? value) =>
      value == null ? null : DateTime.parse(value).toUtc();
  return VehicleAssignment(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    userId: row['user_id'] as String?,
    fromDate: dateFromColumn(row['from_date'] as String),
    toDate: switch (row['to_date'] as String?) {
      null => null,
      final to => dateFromColumn(to),
    },
    handoverOdometerKm: row['handover_odometer_km'] as int?,
    returnOdometerKm: row['return_odometer_km'] as int?,
    note: row['note'] as String?,
    confirmedAt: stamp(row['confirmed_at'] as String?),
    confirmedBy: row['confirmed_by'] as String?,
    // Null once the admin who wrote it deleted their account; the window
    // stays in the log, and the entity's default is what a row from before
    // any author was recorded reads as.
    createdBy: row['created_by'] as String? ?? '',
    createdAt: stamp(row['created_at'] as String?),
  );
}
