import 'data/household_repository.dart';

/// Who inherits the garage when [steppingDown] gives up its only admin role:
/// the longest-standing other member, ties broken by user id — never a
/// driver, who sees one car and must not inherit the console.
///
/// The database applies this rule itself (`ensure_household_has_admin`,
/// migrations 0058 and 0080) after the fact, which is the right place to
/// enforce it and the wrong place to explain it. Mirrored here so the app can
/// say the name *before* somebody steps down. Null when nobody else, or only
/// drivers, would remain: the trigger then keeps the role where it is.
HouseholdMember? successorOf(
  Iterable<HouseholdMember> members, {
  required String steppingDown,
}) {
  final others = [
    for (final member in members)
      if (member.userId != steppingDown && member.role != 'driver') member,
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
