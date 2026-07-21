import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/household_repository.dart';
import 'household_providers.dart';

final membersProvider = FutureProvider<List<HouseholdMember>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) {
    return const [];
  }
  return ref.watch(householdRepositoryProvider).members(household.id);
});

/// Display names by user id, for attributing entries to whoever logged them.
final memberNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final members = await ref.watch(membersProvider.future);
  return {for (final member in members) member.userId: member.displayName};
});
