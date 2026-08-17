import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/maintenance/tracking_level.dart';
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
      return rows.map(serviceTypeFromRow).toList(growable: false);
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
      return rows.map(reminderRuleFromRow).toList(growable: false);
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
      return rows.map(serviceEntryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> upsertRule(ReminderRule rule) async {
    try {
      final payload = reminderRuleToRow(rule);
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
      } else if (rule.id.isNotEmpty) {
        await _client.from('reminder_rules').update(payload).eq('id', rule.id);
      } else {
        // Update first, insert only if nothing matched. Postgres cannot resolve
        // `on conflict (vehicle_id, service_type_key)` here: migration 0014
        // replaced that constraint with a *partial* unique index (`where not
        // one_time`), and a partial index only satisfies ON CONFLICT when the
        // statement repeats its predicate, which PostgREST cannot express. The
        // upsert that used to be here therefore failed with 42P10 on every
        // recurring rule, which is what stopped a Fuelio import halfway.
        final updated = await _client
            .from('reminder_rules')
            .update(payload)
            .eq('vehicle_id', rule.vehicleId)
            .eq('service_type_key', rule.serviceTypeKey)
            .eq('one_time', false)
            .select('id');
        if (updated.isEmpty) {
          await _client.from('reminder_rules').insert(payload);
        }
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
        ...serviceEntryToRow(entry),
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
          .update(serviceEntryToRow(entry))
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
}

ServiceType serviceTypeFromRow(Map<String, dynamic> row) {
  return ServiceType(
    key: row['key'] as String,
    defaultIntervalKm: row['default_interval_km'] as int?,
    defaultIntervalMonths: row['default_interval_months'] as int?,
    isStatutory: row['is_statutory'] as bool? ?? false,
    countryCode: row['country_code'] as String?,
  );
}

/// The writable half of a `reminder_rules` row; `id` is the server's.
Map<String, dynamic> reminderRuleToRow(ReminderRule rule) {
  return {
    'vehicle_id': rule.vehicleId,
    'service_type_key': rule.serviceTypeKey,
    'interval_km': rule.intervalKm,
    'interval_months': rule.intervalMonths,
    'one_time': rule.oneTime,
    'due_date': rule.dueDate == null ? null : dateToColumn(rule.dueDate!),
    'due_odometer_km': rule.dueOdometerKm,
    'active': rule.active,
  };
}

ReminderRule reminderRuleFromRow(Map<String, dynamic> row) {
  final dueDate = row['due_date'] as String?;
  return ReminderRule(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    serviceTypeKey: row['service_type_key'] as String,
    intervalKm: row['interval_km'] as int?,
    intervalMonths: row['interval_months'] as int?,
    oneTime: row['one_time'] as bool? ?? false,
    dueDate: dueDate == null ? null : dateFromColumn(dueDate),
    dueOdometerKm: row['due_odometer_km'] as int?,
    active: row['active'] as bool,
  );
}

/// The writable half of a `service_entries` row; `id` and `created_by` are the
/// server's.
Map<String, dynamic> serviceEntryToRow(ServiceEntry entry) {
  return {
    'vehicle_id': entry.vehicleId,
    'entry_date': dateToColumn(entry.date),
    'odometer_km': entry.odometerKm,
    'service_type_keys': entry.serviceTypeKeys,
    'cost': entry.cost,
    'shop': entry.shop,
    'notes': entry.notes,
    'diy': entry.diy,
    'parts_cost': entry.partsCost,
    'labor_cost': entry.laborCost,
    'parts_detail': entry.partsDetail,
    'warranty_until': entry.warrantyUntil == null
        ? null
        : dateToColumn(entry.warrantyUntil!),
    'measurements': Measurements.toStored(entry.measurements),
    'fault_codes': entry.faultCodes,
  };
}

ServiceEntry serviceEntryFromRow(Map<String, dynamic> row) {
  return ServiceEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    odometerKm: row['odometer_km'] as int,
    serviceTypeKeys: (row['service_type_keys'] as List<dynamic>)
        .map((e) => e as String)
        .toList(growable: false),
    cost: (row['cost'] as num?)?.toDouble(),
    shop: row['shop'] as String?,
    notes: row['notes'] as String?,
    createdBy: row['created_by'] as String? ?? '',
    // Rows written before these columns existed read as "nothing recorded".
    diy: row['diy'] as bool? ?? false,
    partsCost: (row['parts_cost'] as num?)?.toDouble(),
    laborCost: (row['labor_cost'] as num?)?.toDouble(),
    partsDetail: row['parts_detail'] as String?,
    warrantyUntil: row['warranty_until'] == null
        ? null
        : dateFromColumn(row['warranty_until'] as String),
    measurements: Measurements.fromStored(
      (row['measurements'] as Map?)?.cast<String, dynamic>(),
    ),
    faultCodes: row['fault_codes'] as String?,
  );
}
