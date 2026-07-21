import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/household.dart';
import 'household_repository.dart';

class SupabaseHouseholdRepository implements HouseholdRepository {
  SupabaseHouseholdRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Household>> myHouseholds() async {
    try {
      final rows = await _client.from('households').select();
      return rows.map(_toHousehold).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> create(String name) async {
    try {
      // An RPC rather than an insert: the household row and its first
      // membership row must both exist or the creator is locked out of what
      // they just made.
      final id = await _client.rpc<String>(
        'create_household',
        params: {'household_name': name},
      );
      return id;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> joinWithCode(String code) async {
    try {
      final id = await _client.rpc<String>(
        'join_household_with_code',
        params: {'invite_code': code},
      );
      return id;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> createInvite(String householdId) async {
    try {
      final code = await _client.rpc<String>(
        'create_invite',
        params: {'target_household': householdId},
      );
      return code;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<HouseholdMember>> members(String householdId) async {
    try {
      final rows = await _client
          .from('household_members')
          .select('user_id, role, profiles(display_name)')
          .eq('household_id', householdId);
      return rows
          .map(
            (row) => HouseholdMember(
              userId: row['user_id'] as String,
              displayName:
                  (row['profiles'] as Map<String, dynamic>?)?['display_name']
                          as String? ??
                      '',
              role: row['role'] as String,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> leave(String householdId) async {
    try {
      await _client
          .from('household_members')
          .delete()
          .eq('household_id', householdId)
          .eq('user_id', _client.auth.currentUser!.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> updateSettings(Household household) async {
    try {
      await _client.from('households').update({
        'name': household.name,
        'currency_code': household.currencyCode,
        'distance_unit': household.distanceUnit,
        'volume_unit': household.volumeUnit,
        'bundling_window_days': household.bundlingWindowDays,
        'bundling_window_km': household.bundlingWindowKm,
      }).eq('id', household.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Household _toHousehold(Map<String, dynamic> row) {
    return Household(
      id: row['id'] as String,
      name: row['name'] as String,
      currencyCode: row['currency_code'] as String,
      distanceUnit: row['distance_unit'] as String,
      volumeUnit: row['volume_unit'] as String,
      bundlingWindowDays: row['bundling_window_days'] as int,
      bundlingWindowKm: row['bundling_window_km'] as int,
    );
  }
}
