import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import 'maintenance_repository.dart';

class SupabaseMaintenanceRepository implements MaintenanceRepository {
  SupabaseMaintenanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ServiceType>> serviceTypes() async {
    try {
      final rows = await _client.from('service_types').select();
      return rows.map(_toServiceType).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('reminder_rules')
          .select()
          .eq('vehicle_id', vehicleId);
      return rows.map(_toRule).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('service_entries')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('entry_date', ascending: false);
      return rows.map(_toServiceEntry).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> upsertRule(ReminderRule rule) async {
    try {
      await _client.from('reminder_rules').upsert(
        {
          'vehicle_id': rule.vehicleId,
          'service_type_key': rule.serviceTypeKey,
          'interval_km': rule.intervalKm,
          'interval_months': rule.intervalMonths,
          'active': rule.active,
        },
        onConflict: 'vehicle_id,service_type_key',
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> deleteRule(String id) async {
    try {
      await _client.from('reminder_rules').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async {
    try {
      await _client.from('service_entries').insert({
        'vehicle_id': entry.vehicleId,
        'entry_date': entry.date.toUtc().toIso8601String().split('T').first,
        'odometer_km': entry.odometerKm,
        'service_type_keys': entry.serviceTypeKeys,
        'cost': entry.cost,
        'shop': entry.shop,
        'notes': entry.notes,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  ServiceType _toServiceType(Map<String, dynamic> row) {
    return ServiceType(
      key: row['key'] as String,
      defaultIntervalKm: row['default_interval_km'] as int?,
      defaultIntervalMonths: row['default_interval_months'] as int?,
      isStatutory: row['is_statutory'] as bool? ?? false,
      countryCode: row['country_code'] as String?,
    );
  }

  ReminderRule _toRule(Map<String, dynamic> row) {
    return ReminderRule(
      id: row['id'] as String,
      vehicleId: row['vehicle_id'] as String,
      serviceTypeKey: row['service_type_key'] as String,
      intervalKm: row['interval_km'] as int?,
      intervalMonths: row['interval_months'] as int?,
      active: row['active'] as bool,
    );
  }

  ServiceEntry _toServiceEntry(Map<String, dynamic> row) {
    return ServiceEntry(
      id: row['id'] as String,
      vehicleId: row['vehicle_id'] as String,
      date: DateTime.parse('${row['entry_date']}T00:00:00Z'),
      odometerKm: row['odometer_km'] as int,
      serviceTypeKeys: (row['service_type_keys'] as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false),
      cost: (row['cost'] as num?)?.toDouble(),
      shop: row['shop'] as String?,
      notes: row['notes'] as String?,
      createdBy: row['created_by'] as String,
    );
  }
}
