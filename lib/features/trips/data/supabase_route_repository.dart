import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/refused_if_none.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/entities/trip_route.dart';
import 'route_repository.dart';

class SupabaseRouteRepository implements RouteRepository {
  SupabaseRouteRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<TripRoute>> forHousehold(String householdId) async {
    try {
      final rows = await _cache.rows(
        'routes/$householdId',
        () => _client
            .from('routes')
            .select()
            .eq('household_id', householdId)
            .retry(enabled: false),
      );
      return rows.map(routeFromRow).toList(growable: false)
        ..sort(TripRoute.byName);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<TripRoute> add({
    required String householdId,
    required String name,
  }) async {
    try {
      final row = await _client
          .from('routes')
          // Trimmed here as well as in the form: the unique index is on
          // `lower(name)` and does not trim, so " Work" and "Work" would
          // otherwise become two routes with one history each.
          .insert({
            'household_id': householdId,
            'name': name.trim(),
            'created_by': _client.auth.currentUser!.id,
          })
          .select()
          .single();
      return routeFromRow(row);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> rename(String id, String name) async {
    try {
      // Read back: a driver reads the garage's routes and holds no write
      // on them, and a filtered update is zero rows, not an error.
      final written = await _client
          .from('routes')
          .update({'name': name.trim()})
          .eq('id', id)
          .select('id');
      refusedIfNone(written, table: 'routes', write: 'update', id: id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final taken = await _client
          .from('routes')
          .delete()
          .eq('id', id)
          .select('id');
      refusedIfNone(taken, table: 'routes', write: 'delete', id: id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

TripRoute routeFromRow(Map<String, dynamic> row) {
  return TripRoute(
    id: row['id'] as String,
    householdId: row['household_id'] as String,
    name: row['name'] as String,
    createdBy: row['created_by'] as String? ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
  );
}
