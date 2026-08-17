import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../domain/entities/income_entry.dart';
import 'income_repository.dart';

class SupabaseIncomeRepository implements IncomeRepository {
  SupabaseIncomeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<IncomeEntry>> forVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('income_entries')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('entry_date', ascending: false);
      return rows.map(incomeEntryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> add(IncomeEntry entry) async {
    try {
      await _client.from('income_entries').insert({
        ...incomeEntryToRow(entry),
        'vehicle_id': entry.vehicleId,
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> update(IncomeEntry entry) async {
    try {
      await _client
          .from('income_entries')
          .update(incomeEntryToRow(entry))
          .eq('id', entry.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('income_entries').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns an edit may change. `vehicle_id` and `created_by` are set once,
/// on insert, and never rewritten.
Map<String, dynamic> incomeEntryToRow(IncomeEntry entry) {
  return {
    'entry_date': dateToColumn(entry.date),
    'category': entry.category,
    'amount': entry.amount,
    'odometer_km': entry.odometerKm,
    'notes': entry.notes,
  };
}

IncomeEntry incomeEntryFromRow(Map<String, dynamic> row) {
  return IncomeEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    date: dateFromColumn(row['entry_date'] as String),
    category: row['category'] as String,
    amount: (row['amount'] as num).toDouble(),
    odometerKm: row['odometer_km'] as int?,
    notes: row['notes'] as String?,
    createdBy: row['created_by'] as String? ?? '',
  );
}
