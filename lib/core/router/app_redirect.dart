import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/household.dart';

const _authScreens = {'/sign-in', '/sign-up'};

/// Where a user at [location] must be sent, given the two gates every screen
/// sits behind: signed in, then a member of a household.
///
/// A household lookup that is still loading — or that failed, as on an offline
/// cold start — holds the user where they are rather than resolving to "no
/// household", which would walk an existing member into onboarding.
String? garageRedirect({
  required String location,
  required bool signedIn,
  required AsyncValue<Household?> household,
}) {
  final onAuthScreen = _authScreens.contains(location);

  if (!signedIn) {
    return onAuthScreen ? null : '/sign-in';
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
