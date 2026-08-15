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
      return rows.map(householdFromRow).toList(growable: false);
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
      return rows.map(householdMemberFromRow).toList(growable: false);
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
  Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {
    try {
      await _client
          .from('household_members')
          .delete()
          .eq('household_id', householdId)
          .eq('user_id', userId);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> updateSettings(Household household) async {
    try {
      await _client
          .from('households')
          .update(householdSettingsToRow(household))
          .eq('id', household.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// The columns the settings screen may change; membership and id are not
/// settings and never travel with them.
Map<String, dynamic> householdSettingsToRow(Household household) {
  return {
    'name': household.name,
    'currency_code': household.currencyCode,
    'distance_unit': household.distanceUnit,
    'volume_unit': household.volumeUnit,
    'bundling_window_days': household.bundlingWindowDays,
    'bundling_window_km': household.bundlingWindowKm,
    'tracking_level': household.trackingLevel,
    'country_code': household.countryCode,
  };
}

Household householdFromRow(Map<String, dynamic> row) {
  return Household(
    id: row['id'] as String,
    name: row['name'] as String,
    currencyCode: row['currency_code'] as String,
    distanceUnit: row['distance_unit'] as String,
    volumeUnit: row['volume_unit'] as String,
    bundlingWindowDays: row['bundling_window_days'] as int,
    bundlingWindowKm: row['bundling_window_km'] as int,
    // A household saved before the setting existed reads as the simplest
    // level rather than as a missing value.
    trackingLevel: row['tracking_level'] as String? ?? 'beginner',
    countryCode: row['country_code'] as String? ?? 'HR',
  );
}

/// A membership row joined to its profile. A member whose profile row has not
/// materialized yet reads as unnamed rather than breaking the member list.
HouseholdMember householdMemberFromRow(Map<String, dynamic> row) {
  final profile = row['profiles'] as Map<String, dynamic>?;
  return HouseholdMember(
    userId: row['user_id'] as String,
    displayName: profile?['display_name'] as String? ?? '',
    role: row['role'] as String,
  );
}
