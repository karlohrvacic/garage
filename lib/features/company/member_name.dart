import 'package:garage/l10n/app_localizations.dart';

/// A member's name as the console prints it.
///
/// A window and an entry outlive the membership behind them, and the
/// profiles policy hides a name once its owner is no longer a co-member, so
/// the log can carry a user id the list no longer names. That reads as
/// "Former member" everywhere the console names people: a blank read as a
/// bug, and a day nobody had the car is a different fact, said in other
/// words. Only once the list is known: while it is loading or its read
/// failed, nobody is a former member yet, and the caller says so with a
/// sentence rather than through the name.
String memberNameOf(
  AppLocalizations l10n,
  Map<String, String> names,
  String userId,
) {
  return names[userId] ?? l10n.companyFormerMember;
}
