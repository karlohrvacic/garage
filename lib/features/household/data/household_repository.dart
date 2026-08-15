import '../../../domain/entities/household.dart';
import '../../../domain/entities/invite.dart';

class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;
}

abstract interface class HouseholdRepository {
  Future<List<Household>> myHouseholds();

  /// Returns the new household's id.
  Future<String> create(String name);

  /// Redeems an invite code and returns the joined household's id.
  Future<String> joinWithCode(String code);

  /// Returns a fresh 8-character invite code.
  Future<String> createInvite(String householdId);

  /// Every code this household has issued, newest first — including used and
  /// expired ones, because "who did I already invite?" is the question this
  /// answers.
  Future<List<Invite>> invites(String householdId);

  /// Withdraws a code that has not been used. The row is deleted, so the code
  /// stops working immediately.
  Future<void> revokeInvite(String inviteId);

  Future<List<HouseholdMember>> members(String householdId);

  Future<void> leave(String householdId);

  /// Removes somebody else from the household. Admins only — the database
  /// enforces it too, so a client that got this wrong would simply be refused.
  Future<void> removeMember({
    required String householdId,
    required String userId,
  });

  Future<void> updateSettings(Household household);
}
