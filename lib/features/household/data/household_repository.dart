import '../../../domain/entities/household.dart';

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
