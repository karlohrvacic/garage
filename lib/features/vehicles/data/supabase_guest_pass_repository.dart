import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/code_description.dart';
import '../../../domain/entities/guest_pass.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/entities/vehicle_briefing.dart';
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
    required DateTime endsAt,
    DateTime? startsAt,
    String? label,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = false,
    bool canViewHistory = false,
    bool canViewPrices = false,
  }) async {
    try {
      // An RPC rather than an insert: the code has to be allocated against
      // every code already out there, and an insert choosing its own could
      // pick one somebody is currently holding.
      return await _client.rpc<String>(
        'create_guest_pass_between',
        params: {
          'target_vehicle': vehicleId,
          'ends_on': endsAt.toUtc().toIso8601String(),
          'starts_on': startsAt?.toUtc().toIso8601String(),
          'pass_label': label,
          'allow_fuel': canLogFuel,
          'allow_trips': canLogTrips,
          'allow_costs': canLogCosts,
          'allow_history': canViewHistory,
          'allow_prices': canViewPrices,
        },
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> extend(String id, DateTime endsAt) async {
    try {
      // A plain update: the owner's policy on the table already allows it,
      // and the table's own check keeps the window the right way round.
      await _client
          .from('vehicle_guest_passes')
          .update({'expires_at': endsAt.toUtc().toIso8601String()})
          .eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<CodeDescription?> describe(String code) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>?>(
        'describe_code',
        params: {'candidate': code},
      );
      if (json == null) {
        return null;
      }
      final kind = CodeKind.fromKey(json['kind'] as String);
      if (kind == null) {
        return null;
      }
      return CodeDescription(
        kind: kind,
        subject: json['subject'] as String? ?? '',
        until: DateTime.parse(json['until'] as String).toUtc(),
        spent: json['spent'] as bool? ?? false,
        member: json['member'] as bool? ?? false,
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> updatePermissions(GuestPass pass) async {
    try {
      // The owner's own update policy on the table. The pass is read by
      // `guest_vehicle_ids` on every request, so a change bites immediately
      // on the code the holder already has.
      await _client
          .from('vehicle_guest_passes')
          .update({
            'can_log_fuel': pass.canLogFuel,
            'can_log_trips': pass.canLogTrips,
            'can_log_costs': pass.canLogCosts,
            'can_view_history': pass.canViewHistory,
            'can_view_prices': pass.canViewHistory && pass.canViewPrices,
          })
          .eq('id', pass.id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<VehicleBriefing?> briefing(String vehicleId) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>?>(
        'guest_vehicle_briefing',
        params: {'target_vehicle': vehicleId},
      );
      return vehicleBriefingFromJson(json);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<ServiceEntry>> serviceHistory(String vehicleId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'guest_service_history',
        params: {'target_vehicle': vehicleId},
      );
      return rows
          .cast<Map<String, dynamic>>()
          .map(lentServiceEntryFromRow)
          .toList(growable: false);
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
  Future<void> giveBack(String id) async {
    try {
      // A definer function, not the table: the update policy on
      // `vehicle_guest_passes` belongs to the garage, and this is the one
      // thing about a pass its holder gets to decide.
      await _client.rpc<void>('return_guest_pass', params: {'pass_id': id});
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

VehicleBriefing? vehicleBriefingFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }
  DateTime? date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  List<T> each<T>(Object? list, T Function(Map<String, dynamic>) map) => [
    for (final row in (list as List<dynamic>? ?? const []))
      map(row as Map<String, dynamic>),
  ];

  return VehicleBriefing(
    odometerKm: (json['odometer_km'] as num?)?.toInt(),
    documents: each(
      json['documents'],
      (row) => BriefedDocument(
        type: row['type'] as String,
        expiresOn: date(row['expires_on'])!,
      ),
    ),
    problems: each(
      json['problems'],
      (row) => BriefedProblem(
        note: row['note'] as String,
        noticedOn: date(row['noticed_on'])!,
      ),
    ),
    tyres: each(
      json['tyres'],
      (row) => BriefedTyres(
        season: row['season'] as String,
        fittedOn: date(row['fitted_on']),
      ),
    ),
  );
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
    returnedAt: at('returned_at'),
    redeemedBy: row['redeemed_by'] as String?,
    redeemedAt: at('redeemed_at'),
    canLogFuel: row['can_log_fuel'] as bool? ?? true,
    canLogTrips: row['can_log_trips'] as bool? ?? true,
    canLogCosts: row['can_log_costs'] as bool? ?? true,
    canViewHistory: row['can_view_history'] as bool? ?? false,
    canViewPrices: row['can_view_prices'] as bool? ?? false,
  );
}

/// A row from `guest_service_history`, which returns the columns a borrower
/// may read and nothing else.
///
/// `created_by` is not among them — who logged it is the garage's business —
/// so it comes back empty, the same way an entry whose author was deleted
/// does. A null `cost` is either "nothing was recorded" or "the pass does not
/// carry prices"; the screen knows which from the pass, not from the row.
ServiceEntry lentServiceEntryFromRow(Map<String, dynamic> row) {
  return ServiceEntry(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String? ?? '',
    date: DateTime.parse(row['entry_date'] as String).toUtc(),
    odometerKm: (row['odometer_km'] as num).toInt(),
    serviceTypeKeys: (row['service_type_keys'] as List<dynamic>)
        .cast<String>()
        .toList(growable: false),
    createdBy: '',
    cost: (row['cost'] as num?)?.toDouble(),
    shop: row['shop'] as String?,
    notes: row['notes'] as String?,
  );
}
