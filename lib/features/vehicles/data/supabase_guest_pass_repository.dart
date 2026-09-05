import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/guest_pass.dart';
import 'guest_pass_repository.dart';

class SupabaseGuestPassRepository implements GuestPassRepository {
  SupabaseGuestPassRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GuestPass>> forVehicle(String vehicleId) async {
    try {
      final rows = await _client
          .from('vehicle_guest_passes')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false);
      return rows.map(guestPassFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<GuestPass>> mine() async {
    try {
      // No filter: the holder's own policy already narrows this to the passes
      // they redeemed, and a `redeemed_by` filter here would need the user id
      // the client may not have yet on a cold start.
      final rows = await _client.from('vehicle_guest_passes').select();
      final userId = _client.auth.currentUser?.id;
      return rows
          .map(guestPassFromRow)
          .where((pass) => pass.redeemedBy != null && pass.redeemedBy == userId)
          .toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> create({
    required String vehicleId,
    required int validDays,
    String? label,
    DateTime? startsAt,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
  }) async {
    try {
      // An RPC rather than an insert: the code has to be allocated against
      // every code already out there, and an insert choosing its own could
      // pick one somebody is currently holding.
      return await _client.rpc<String>(
        'create_guest_pass',
        params: {
          'target_vehicle': vehicleId,
          'valid_days': validDays,
          'pass_label': label,
          'starts_on': startsAt?.toIso8601String(),
          'allow_fuel': canLogFuel,
          'allow_trips': canLogTrips,
          'allow_costs': canLogCosts,
          'allow_history': canViewHistory,
        },
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> revoke(String id) async {
    try {
      // Marked, not deleted. The record of who had the car and when is worth
      // more than a tidy table, and the rows they logged point back at it.
      await _client
          .from('vehicle_guest_passes')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> redeem(String code) async {
    try {
      return await _client.rpc<String>(
        'redeem_guest_pass',
        params: {'pass_code': code.trim().toUpperCase()},
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

GuestPass guestPassFromRow(Map<String, dynamic> row) {
  DateTime? at(String column) {
    final value = row[column] as String?;
    return value == null ? null : DateTime.parse(value).toUtc();
  }

  return GuestPass(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    code: row['code'] as String,
    createdBy: row['created_by'] as String? ?? '',
    createdAt: at('created_at')!,
    expiresAt: at('expires_at')!,
    label: row['label'] as String?,
    startsAt: at('starts_at'),
    revokedAt: at('revoked_at'),
    redeemedBy: row['redeemed_by'] as String?,
    redeemedAt: at('redeemed_at'),
    canLogFuel: row['can_log_fuel'] as bool? ?? true,
    canLogTrips: row['can_log_trips'] as bool? ?? true,
    canLogCosts: row['can_log_costs'] as bool? ?? true,
    canViewHistory: row['can_view_history'] as bool? ?? false,
  );
}
