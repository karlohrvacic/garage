import 'data/household_repository.dart';

/// Who inherits the garage when [steppingDown] gives up its only admin role:
/// the longest-standing other member, ties broken by user id.
///
/// The database applies this rule itself — `ensure_household_has_admin`,
/// migration 0058 — after the fact, which is the right place to enforce it
/// and the wrong place to explain it. Mirrored here so the app can say the
/// name *before* somebody steps down, instead of leaving them to find out
/// from the list who has their garage now. Null when there is nobody else;
/// the trigger then leaves the role where it is.
HouseholdMember? successorOf(
  Iterable<HouseholdMember> members, {
  required String steppingDown,
}) {
  final others = [
    for (final member in members)
      if (member.userId != steppingDown) member,
  ]..sort(_byTenure);
  return others.isEmpty ? null : others.first;
}

int _byTenure(HouseholdMember a, HouseholdMember b) {
  // A member whose join date never arrived sorts last: the rule prefers who
  // it can vouch for, and a fake in a test may not have said.
  final byDate = switch ((a.joinedAt, b.joinedAt)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    (final first?, final second?) => first.compareTo(second),
  };
  return byDate != 0 ? byDate : a.userId.compareTo(b.userId);
}
