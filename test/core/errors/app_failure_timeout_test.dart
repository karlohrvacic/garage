import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';

void main() {
  test(
    'a write that times out is a network failure, not "something went wrong"',
    () {
      final failure = AppFailure.from(
        TimeoutException('write', const Duration(seconds: 20)),
      );
      expect(failure.kind, AppFailureKind.timeout);
    },
  );
}
