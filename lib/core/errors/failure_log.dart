import 'dart:developer' as developer;

import 'app_failure.dart';

/// How many failures are kept. Enough to cover what a tester did just before
/// writing to you; short enough that it is never a store of user data.
const failureLogLimit = 20;

final List<String> _recorded = [];

/// The recent failures, oldest first. Read by the About screen's diagnostics
/// and by tests; nothing here leaves the device unless someone copies it.
List<String> get recordedFailures => List.unmodifiable(_recorded);

/// Records a failure on its way to the user.
///
/// [AppFailure.debugMessage] carries the only description of what actually
/// went wrong — an `AuthApiException` message, a Postgrest code — and the
/// screens deliberately show a generic sentence instead. Without this, that
/// description was constructed and then dropped, which is how "something went
/// wrong" became the whole of what anyone could report.
void reportFailure(AppFailure failure) {
  final line = '${failure.kind.name}: ${failure.debugMessage ?? "no detail"}';
  developer.log(line, name: 'garage.failure');
  _recorded.add(line);
  if (_recorded.length > failureLogLimit) {
    _recorded.removeRange(0, _recorded.length - failureLogLimit);
  }
}

/// Forgets everything recorded. For tests, and for a "clear" action if the
/// diagnostics ever become user-visible.
void clearRecordedFailures() => _recorded.clear();
