import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's date, injected so projections are deterministic under test.
///
/// Re-evaluates itself at the next local midnight: a session left open for
/// days (a pinned browser tab) would otherwise keep judging due/overdue
/// against the day the app was opened.
///
/// Lives in `core/` rather than beside the maintenance providers because it is
/// a platform seam like [urlOpenerProvider] and the file picker, not a
/// maintenance concept — and because the odometer providers need it too, which
/// from the maintenance library would have been an import cycle.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(nextMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});
