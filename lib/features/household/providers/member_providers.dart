import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/invite.dart';
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

/// Whether the signed-in user may take the household's two destructive
/// actions: removing a vehicle, and removing somebody else.
///
/// A household of one is always its member's, whatever the stored role says —
/// somebody who joined by code and then outlived everyone else must not end up
/// locked out of their own data.
final isHouseholdAdminProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return false;
  }
  final members = await ref.watch(membersProvider.future);
  if (members.length == 1) {
    return members.single.userId == userId;
  }
  for (final member in members) {
    if (member.userId == userId) {
      return member.role == 'admin';
    }
  }
  return false;
});

/// Every invite code this household has issued, newest first.
///
/// Kept next to the members list because it answers the other half of "who is
/// in this household?" — the people who were asked and have not arrived yet.
final householdInvitesProvider = FutureProvider<List<Invite>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) {
    return const [];
  }
  return ref.watch(householdRepositoryProvider).invites(household.id);
});
