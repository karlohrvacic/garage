import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show ProviderOrFamily;

import '../../household/providers/household_providers.dart';

/// The Retry of a console tab whose list derives from every car's rows.
///
/// Invalidating the aggregate alone would re-await whichever [leaves] still
/// caches the error, so they are invalidated with it, and the startup fetch
/// they all hang off (the bootstrap is the one to refresh, never the vehicle
/// lists derived from it).
VoidCallback fleetRetry(WidgetRef ref, List<ProviderOrFamily> leaves) {
  return () {
    ref.invalidate(garageBootstrapProvider);
    for (final leaf in leaves) {
      ref.invalidate(leaf);
    }
  };
}
