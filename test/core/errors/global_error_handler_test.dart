import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/core/errors/global_error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Installing the handlers replaces process-wide state that `flutter_test`
/// relies on to fail tests, so every case puts back what it found.
void main() {
  late FlutterExceptionHandler? previousFlutterHandler;
  late ErrorCallback? previousPlatformHandler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearRecordedFailures();
    previousFlutterHandler = FlutterError.onError;
    previousPlatformHandler = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
    resetGlobalErrorHandlersForTesting();
  });

  test('a framework error is recorded rather than only printed', () {
    installGlobalErrorHandlers();

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('a widget exploded')),
    );

    expect(recordedFailures.single, contains('a widget exploded'));
  });

  test('the handler that was already there still runs', () {
    var reachedPrevious = false;
    FlutterError.onError = (_) => reachedPrevious = true;

    installGlobalErrorHandlers();
    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('a widget exploded')),
    );

    expect(
      reachedPrevious,
      isTrue,
      reason:
          'flutter_test installs its own handler to fail tests on framework '
          'errors, and a handler that swallows it would turn every future red '
          'test green',
    );
  });

  test('an uncaught asynchronous error is recorded', () {
    installGlobalErrorHandlers();

    PlatformDispatcher.instance.onError!(
      StateError('nobody awaited this'),
      StackTrace.empty,
    );

    expect(recordedFailures.single, contains('nobody awaited this'));
  });

  test('an uncaught error is still reported as unhandled', () {
    installGlobalErrorHandlers();

    final handled = PlatformDispatcher.instance.onError!(
      StateError('nobody awaited this'),
      StackTrace.empty,
    );

    expect(
      handled,
      isFalse,
      reason:
          'this handler observes, it does not resolve. Claiming the error was '
          'handled would stop the platform logging it and hide it from the '
          'one place that currently shows it: the console.',
    );
  });

  test('installing twice does not record the same failure twice', () {
    installGlobalErrorHandlers();
    installGlobalErrorHandlers();

    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('a widget exploded')),
    );

    expect(
      recordedFailures,
      hasLength(1),
      reason: 'chaining onto our own handler would double every entry',
    );
  });
}
