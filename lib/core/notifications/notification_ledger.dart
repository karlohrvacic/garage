import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which dated reminder notices have been given on this device, by
/// `ScheduledReminder.cycles`.
///
/// A sync cancels every scheduled notice and plans again, so the plan alone
/// cannot say which notices were already given: a notice whose moment had
/// passed was given again on every launch that day. This remembers what was
/// scheduled, and when, so a notice counts as given once its moment has gone.
abstract class NotificationLedger {
  /// The cycles given by [now]: recorded as given, or scheduled for a moment
  /// that has passed.
  Future<Set<String>> firedBy(DateTime now);

  /// What was just [scheduled], and the [fired] cycles still worth keeping.
  /// A cycle left out is forgotten: once its work is logged the next cycle has
  /// a key of its own, and the old one is never projected again.
  Future<void> remember({
    required Map<String, DateTime> scheduled,
    required Set<String> fired,
  });
}

final notificationLedgerProvider = Provider<NotificationLedger>(
  (ref) => const PrefsNotificationLedger(),
);

/// The ledger kept in the device's preferences, beside the rest of this
/// device's state.
class PrefsNotificationLedger implements NotificationLedger {
  const PrefsNotificationLedger();

  static const _scheduledKey = 'notification_ledger_scheduled';
  static const _firedKey = 'notification_ledger_fired';

  @override
  Future<Set<String>> firedBy(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final fired = {...?prefs.getStringList(_firedKey)};
    final scheduled = prefs.getString(_scheduledKey);
    if (scheduled != null) {
      final entries = jsonDecode(scheduled) as Map<String, dynamic>;
      for (final MapEntry(key: cycle, value: at) in entries.entries) {
        final moment = DateTime.tryParse('$at');
        if (moment != null && !moment.isAfter(now)) {
          fired.add(cycle);
        }
      }
    }
    return fired;
  }

  @override
  Future<void> remember({
    required Map<String, DateTime> scheduled,
    required Set<String> fired,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scheduledKey,
      jsonEncode({
        for (final MapEntry(key: cycle, value: at) in scheduled.entries)
          cycle: at.toIso8601String(),
      }),
    );
    await prefs.setStringList(_firedKey, fired.toList()..sort());
  }
}

/// A ledger that lives as long as it does, for tests: the preferences one
/// waits forever in a test that set no mock values, and a sync then never
/// reaches the service.
class InMemoryNotificationLedger implements NotificationLedger {
  var _scheduled = <String, DateTime>{};
  var _fired = <String>{};

  @override
  Future<Set<String>> firedBy(DateTime now) async => {
    ..._fired,
    for (final MapEntry(key: cycle, value: at) in _scheduled.entries)
      if (!at.isAfter(now)) cycle,
  };

  @override
  Future<void> remember({
    required Map<String, DateTime> scheduled,
    required Set<String> fired,
  }) async {
    _scheduled = {...scheduled};
    _fired = {...fired};
  }
}
