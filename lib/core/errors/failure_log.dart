import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_failure.dart';

/// How many failures are kept. Enough to cover what a tester did just before
/// writing to you; short enough that it is never a store of user data.
const failureLogLimit = 20;

/// Where the log lives between runs.
const _storageKey = 'diagnostics.failures';

final List<String> _recorded = [];

/// The last write in flight, so tests and a "clear" can wait for the disk.
///
/// Recording is deliberately synchronous — it happens on the way to showing
/// the user a message and must not make callers wait for storage — so the
/// write is started and not awaited. That would be a silent failure if the
/// write could be lost without anyone knowing, which is why it is kept here
/// rather than dropped.
Future<void> _pending = Future.value();

/// Completes when everything reported so far has reached storage.
Future<void> get pendingFailureWrites => _pending;

/// The recent failures, oldest first. Read by the About screen's diagnostics
/// and by tests; nothing here leaves the device unless someone shares it.
List<String> get recordedFailures => List.unmodifiable(_recorded);

/// Records a failure on its way to the user.
///
/// [AppFailure.debugMessage] carries the only description of what actually
/// went wrong — an `AuthApiException` message, a Postgrest code — and the
/// screens deliberately show a generic sentence instead. Without this, that
/// description was constructed and then dropped, which is how "something went
/// wrong" became the whole of what anyone could report.
void reportFailure(AppFailure failure) {
  final line =
      '${_stamp(DateTime.now())} '
      '${failure.kind.name}: ${failure.debugMessage ?? "no detail"}';
  developer.log(line, name: 'garage.failure');
  _recorded.add(line);
  if (_recorded.length > failureLogLimit) {
    _recorded.removeRange(0, _recorded.length - failureLogLimit);
  }
  _persist();
}

/// Reads back what earlier runs recorded. Called once at startup.
///
/// A crash is a restart, so the failure most worth reading is exactly the one
/// an in-memory log has already forgotten by the time anyone goes looking.
///
/// Stored entries go in *front* of anything recorded so far rather than
/// replacing it. Startup installs the error handlers before it gets here, so
/// a failure during startup is the one case where this races — and it is also
/// the case where losing the entry would matter most.
Future<void> loadRecordedFailures() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList(_storageKey);
  if (stored == null || stored.isEmpty) {
    return;
  }
  _recorded.insertAll(0, stored);
  if (_recorded.length > failureLogLimit) {
    _recorded.removeRange(0, _recorded.length - failureLogLimit);
  }
}

/// Forgets everything recorded, on screen and on disk.
Future<void> clearRecordedFailures() async {
  _recorded.clear();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_storageKey);
}

/// Drops the in-memory copy without touching storage. For tests that need to
/// act out a restart; nothing in the app has a reason to call this.
@visibleForTesting
void forgetRecordedFailuresInMemory() => _recorded.clear();

void _persist() {
  _pending = _pending.then((_) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, List.of(_recorded));
    } catch (error) {
      // Best effort, and deliberately so: an app must not fall over because
      // it could not write its own error log. Storage can be full, and on the
      // web it can be denied outright in a private window. The in-memory log
      // still works, so the run stays diagnosable — and this goes to the same
      // channel as everything else rather than vanishing, because a
      // diagnostics feature that fails quietly is worse than none.
      developer.log(
        'could not persist the failure log: $error',
        name: 'garage.failure',
      );
    }
  });
}

/// `2026-08-17 14:03:11`, local time — the form someone can compare against
/// their own memory of when it went wrong. Not ISO 8601: the `T` and the zone
/// offset are noise to the person reading this out of a bug report.
String _stamp(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
}
