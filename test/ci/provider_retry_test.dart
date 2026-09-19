import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/provider_retry.dart';

/// Riverpod rebuilds a provider whose build threw, ten times with a growing
/// pause, and shows the loading branch the whole while: a refused read spun
/// for some forty seconds and asked the server ten more times before its
/// failure sentence appeared. The app's scope turns that off (decision 185),
/// and this holds the switch in place.
void main() {
  test('a provider that failed stays failed, with nothing pending', () async {
    final container = ProviderContainer(retry: noProviderRetry);
    addTearDown(container.dispose);
    final refused = FutureProvider<int>((ref) async {
      throw const AppFailure(kind: AppFailureKind.permission);
    });

    await expectLater(
      container.read(refused.future),
      throwsA(isA<AppFailure>()),
    );

    final state = container.read(refused);
    expect(state.hasError, isTrue);
    // Loading here would be the retry: the error tucked into a loading state
    // with a timer behind it.
    expect(state.isLoading, isFalse);
    expect(state, isA<AsyncError<int>>());
  });

  test('the app\'s scope passes the switch', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains('ProviderScope(retry: noProviderRetry'),
      reason:
          'lib/main.dart must build its ProviderScope with '
          'retry: noProviderRetry, or every failed read spins for forty '
          'seconds before it says why',
    );
  });
}
