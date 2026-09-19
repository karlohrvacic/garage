import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../core/supabase/refused_if_none.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/company/payment_method.dart';
import '../../../domain/entities/cost_entry.dart';
import '../../../domain/maintenance/recurring_costs.dart';
import 'cost_repository.dart';

class SupabaseCostRepository implements CostRepository {
  SupabaseCostRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async {
    try {
      final rows = await _cache.rows(
        'costs/$vehicleId',
        () => _client
            .from('cost_entries')
            .select()
            .eq('vehicle_id', vehicleId)
            .order('entry_date', ascending: false)
            .retry(enabled: false),
      );
      return rows.map(costEntryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(CostEntry entry) async {
    try {
      await _client.from('cost_entries').insert({
        // The sheet's own id, so a retry after a timeout is the same row.
        if (entry.id.isNotEmpty) 'id': entry.id,
        ...costEntryToRow(entry),
        'vehicle_id': entry.vehicleId,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(CostEntry entry) async {
    try {
      final written = await _client
          .from('cost_entries')
          .update(costEntryToRow(entry))
          .eq('id', entry.id)
          .select('id');
      refusedIfNone(
        written,
        table: 'cost_entries',
        write: 'update',
        id: entry.id,
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final taken = await _client
          .from('cost_entries')
          .delete()
          .eq('id', id)
          .select('id');
      refusedIfNone(taken, table: 'cost_entries', write: 'delete', id: id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set once,
/// on insert, and never rewritten.
Map<String, dynamic> costEntryToRow(CostEntry entry) {
  return {
    'entry_date': dateToColumn(entry.date),
    'category': entry.category,
    'amount': entry.amount,
    'odometer_km': entry.odometerKm,
    'notes': entry.notes,
    'vignette_country': entry.vignetteCountry?.code,
    'vignette_validity': entry.vignetteValidity?.key,
    // Never `reimbursed_at`: the console stamps it, and the trigger would
    // refuse a driver's edit that carried a stale value.
    'paid_with': entry.paidWith?.key,
  };
}

CostEntry costEntryFromRow(Map<String, dynamic> row) {
  return CostEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    category: row['category'] as String,
    amount: (row['amount'] as num).toDouble(),
    odometerKm: row['odometer_km'] as int?,
    notes: row['notes'] as String?,
    createdBy: row['created_by'] as String? ?? '',
    vignetteCountry: switch (row['vignette_country']) {
      final String code => VignetteCountry.fromCode(code),
      _ => null,
    },
    vignetteValidity: switch (row['vignette_validity']) {
      final String key => VignetteValidity.fromKey(key),
      _ => null,
    },
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    paidWith: PaymentMethod.fromKey(row['paid_with'] as String?),
    reimbursedAt: switch (row['reimbursed_at'] as String?) {
      null => null,
      final at => DateTime.parse(at).toUtc(),
    },
  );
}
