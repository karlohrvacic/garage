import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';

void main() {
  setUp(clearRecordedFailures);

  test('a failure shown to someone is recorded with its cause', () {
    reportFailure(
      const AppFailure(
        kind: AppFailureKind.unknown,
        debugMessage: 'GoogleSignInException: audience mismatch',
      ),
    );

    expect(recordedFailures, hasLength(1));
    expect(
      recordedFailures.single,
      contains('GoogleSignInException: audience mismatch'),
      reason: 'the cause is the whole reason this exists',
    );
  });

  test('the kind is recorded too, since the message can be null', () {
    reportFailure(const AppFailure(kind: AppFailureKind.network));

    expect(recordedFailures.single, contains('network'));
  });

  test('only the most recent failures are kept', () {
    for (var i = 0; i < failureLogLimit + 10; i++) {
      reportFailure(
        AppFailure(kind: AppFailureKind.unknown, debugMessage: 'failure $i'),
      );
    }

    expect(recordedFailures, hasLength(failureLogLimit));
    expect(
      recordedFailures.last,
      contains('failure ${failureLogLimit + 9}'),
      reason: 'a tester reports the last thing that happened, not the first',
    );
  });
}
