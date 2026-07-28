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
      final payload = {
        'vehicle_id': rule.vehicleId,
        'service_type_key': rule.serviceTypeKey,
        'interval_km': rule.intervalKm,
        'interval_months': rule.intervalMonths,
        'one_time': rule.oneTime,
        'due_date': rule.dueDate?.toUtc().toIso8601String().split('T').first,
        'due_odometer_km': rule.dueOdometerKm,
        'active': rule.active,
      };
      if (rule.oneTime) {
        // One-time rules are not unique per type, so no conflict target
        // exists: a known id updates, a blank one inserts.
        if (rule.id.isEmpty) {
          await _client.from('reminder_rules').insert(payload);
        } else {
          await _client
              .from('reminder_rules')
              .update(payload)
              .eq('id', rule.id);
        }
      } else {
        await _client
            .from('reminder_rules')
            .upsert(payload, onConflict: 'vehicle_id,service_type_key');
      }
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) async {
    try {
      await _client
          .from('reminder_rules')
          .update({'active': false})
          .eq('vehicle_id', vehicleId)
          .eq('one_time', true)
          .eq('active', true)
          .inFilter('service_type_key', serviceTypeKeys);
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

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {
    try {
      await _client
          .from('service_entries')
          .update({
            'entry_date': entry.date.toUtc().toIso8601String().split('T').first,
            'odometer_km': entry.odometerKm,
            'service_type_keys': entry.serviceTypeKeys,
            'cost': entry.cost,
            'shop': entry.shop,
            'notes': entry.notes,
          })
          .eq('id', entry.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> deleteServiceEntry(String id) async {
    try {
      await _client.from('service_entries').delete().eq('id', id);
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
    final dueDate = row['due_date'] as String?;
    return ReminderRule(
      id: row['id'] as String,
      vehicleId: row['vehicle_id'] as String,
      serviceTypeKey: row['service_type_key'] as String,
      intervalKm: row['interval_km'] as int?,
      intervalMonths: row['interval_months'] as int?,
      oneTime: row['one_time'] as bool? ?? false,
      dueDate: dueDate == null ? null : DateTime.parse('${dueDate}T00:00:00Z'),
      dueOdometerKm: row['due_odometer_km'] as int?,
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
