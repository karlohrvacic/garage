import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/household/settlement.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'member_providers.dart';

/// What each member has paid into the household's vehicles: every fill-up,
/// service, and cost, attributed to whoever logged it.
///
/// Members who have logged nothing appear at zero — they are still part of the
/// split. Spend logged by someone who has since left the household stays in:
/// their money went into these vehicles, and dropping it would quietly rewrite
/// what everyone else owes.
final householdSpendByMemberProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  final members = await ref.watch(membersProvider.future);

  final spend = <String, double>{
    for (final member in members) member.userId: 0,
  };
  void add(String userId, double? amount) {
    if (amount == null) {
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

  return spend;
});

/// Who is ahead, who is behind, and the payments that would even it out.
final settlementProvider = FutureProvider<Settlement>((ref) async {
  return Settlement.of(
    spendByMember: await ref.watch(householdSpendByMemberProvider.future),
  );
});
