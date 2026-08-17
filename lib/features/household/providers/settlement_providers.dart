import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/household/settlement.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'member_providers.dart';

/// What each member has paid into the household's vehicles, and what was paid
/// by somebody who is no longer anybody.
class HouseholdSpend {
  const HouseholdSpend({required this.byMember, required this.unattributed});

  /// Keyed by user id. Includes members who have logged nothing, at zero — they
  /// are still part of the split — and people who have *left* the household but
  /// still exist: their money went into these vehicles and they can still be
  /// settled with.
  final Map<String, double> byMember;

  /// Spend whose author deleted their account, so `created_by` is null. There
  /// is nobody left to pay or be paid, which is exactly why it cannot be a
  /// participant in the split.
  final double unattributed;
}

/// What each member has paid into the household's vehicles: every fill-up,
/// service, and cost, attributed to whoever logged it.
final householdSpendByMemberProvider = FutureProvider<HouseholdSpend>((
  ref,
) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  final members = await ref.watch(membersProvider.future);

  final spend = <String, double>{
    for (final member in members) member.userId: 0,
  };
  var unattributed = 0.0;
  void add(String userId, double? amount) {
    if (amount == null) {
      return;
    }
    // An empty author is what a deleted account leaves behind. Adding it to
    // the map made it a participant: the fair share was divided by one head
    // too many, and the household was told it owed money to a blank name.
    if (userId.isEmpty) {
      unattributed += amount;
      return;
    }
    spend[userId] = (spend[userId] ?? 0) + amount;
  }

  await Future.wait([
    for (final vehicle in vehicles)
      Future(() async {
        final fuel = await ref.watch(rawFuelEntriesProvider(vehicle.id).future);
        final services = await ref.watch(
          serviceEntriesProvider(vehicle.id).future,
        );
        final costs = await ref.watch(costEntriesProvider(vehicle.id).future);

        for (final entry in fuel) {
          add(entry.createdBy, entry.total);
        }
        for (final entry in services) {
          add(entry.createdBy, entry.cost);
        }
        for (final entry in costs) {
          add(entry.createdBy, entry.amount);
        }
      }),
  ]);

  return HouseholdSpend(byMember: spend, unattributed: unattributed);
});

/// Who is ahead, who is behind, and the payments that would even it out.
final settlementProvider = FutureProvider<Settlement>((ref) async {
  final spend = await ref.watch(householdSpendByMemberProvider.future);
  return Settlement.of(
    spendByMember: spend.byMember,
    unattributed: spend.unattributed,
  );
});
