import '../../../domain/entities/household.dart';

abstract interface class HouseholdRepository {
  Future<List<Household>> myHouseholds();

  /// Returns the new household's id.
  Future<String> create(String name);

  /// Redeems an invite code and returns the joined household's id.
  Future<String> joinWithCode(String code);

  /// Returns a fresh 8-character invite code.
  Future<String> createInvite(String householdId);
}
