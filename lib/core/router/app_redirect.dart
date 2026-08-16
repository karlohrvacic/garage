import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/household.dart';

const _authScreens = {'/sign-in', '/sign-up'};

/// Where an invite link lands. See [garageRedirect] for why it sits outside
/// both gates.
const joinRoute = '/join';

/// Where a user at [location] must be sent, given the two gates every screen
/// sits behind: signed in, then a member of a household.
///
/// A household lookup that is still loading — or that failed, as on an offline
/// cold start — holds the user where they are rather than resolving to "no
/// household", which would walk an existing member into onboarding.
///
/// [pendingInvite] is a code from a link the visitor opened before signing in.
/// Signing in navigates to "/", which would strand it, so once they are
/// through the first gate they are carried back to the invite.
String? garageRedirect({
  required String location,
  required bool signedIn,
  required AsyncValue<Household?> household,
  String? pendingInvite,
}) {
  // An invite link is opened by someone who by definition has no household and
  // often no account. Both gates would bounce them: to sign-in, which loses the
  // code, and then to onboarding, which asks them to type it in. The join
  // screen handles every one of those states itself.
  if (location.startsWith('$joinRoute/')) {
    return null;
  }

  final onAuthScreen = _authScreens.contains(location);

  if (!signedIn) {
    return onAuthScreen ? null : '/sign-in';
  }

  if (pendingInvite != null) {
    return '$joinRoute/$pendingInvite';
  }

  if (onAuthScreen) {
    return '/';
  }

  if (household.isLoading || household.hasError) {
    return null;
  }

  final needsOnboarding = household.value == null;
  if (needsOnboarding && location != '/onboarding') {
    return '/onboarding';
  }
  if (!needsOnboarding && location == '/onboarding') {
    return '/';
  }
  return null;
}
