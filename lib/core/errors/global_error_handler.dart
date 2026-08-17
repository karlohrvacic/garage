import 'package:flutter/foundation.dart';

import 'app_failure.dart';
import 'failure_log.dart';

bool _installed = false;

/// Sends errors nobody caught to the same log as the ones screens report.
///
/// Until this existed, a failure only reached [reportFailure] if some screen
/// had thought to route it there. Everything else — a build that threw, a
/// future nobody awaited, a plugin that failed on a background isolate —
/// printed to a console that no user has, and the app's own diagnostics said
/// the run had been clean. The gap was widest exactly where it mattered most,
/// because a crash leaves no screen behind to report anything.
///
/// This observes; it does not resolve. Both handlers pass the error on, so the
/// framework still turns a build error red in debug and the platform still
/// logs what it always logged.
void installGlobalErrorHandlers() {
  // Installing twice would chain this handler onto itself and record every
  // error once per installation. Guarded rather than documented, because the
  // duplicate entries would look like the app failing repeatedly.
  if (_installed) {
    return;
  }
  _installed = true;

  final framework = FlutterError.onError;
  FlutterError.onError = (details) {
    reportFailure(AppFailure.from(details.exception));
    // `flutter_test` installs a handler here to fail tests on framework
    // errors, and the default one prints the red-screen dump. Replacing
    // either would be a silent failure of its own.
    framework?.call(details);
  };

  final platform = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    reportFailure(AppFailure.from(error));
    // False means "not handled": the error carries on to whatever handled it
    // before, which is the console. Returning true would make the app quieter
    // by hiding errors, which is the opposite of the point.
    return platform?.call(error, stack) ?? false;
  };
}

/// Puts the handlers back to whatever the process started with. Tests only.
@visibleForTesting
void resetGlobalErrorHandlersForTesting() => _installed = false;
