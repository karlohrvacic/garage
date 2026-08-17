import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearRecordedFailures();
  });

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

  test('a failure says when it happened', () {
    reportFailure(const AppFailure(kind: AppFailureKind.network));

    // "It failed at some point" is not a bug report. A time is what lets
    // someone line the entry up with what they were doing.
    expect(
      recordedFailures.single,
      matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} ')),
    );
  });

  test(
    'failures survive a restart, which is when they are actually read',
    () async {
      reportFailure(
        const AppFailure(
          kind: AppFailureKind.auth,
          debugMessage: 'token refresh failed',
        ),
      );
      await pendingFailureWrites;

      // What a restart looks like from here: the process forgets, storage does
      // not. A crash *is* a restart, so an in-memory log loses precisely the
      // failure worth reading.
      forgetRecordedFailuresInMemory();
      expect(recordedFailures, isEmpty);

      await loadRecordedFailures();

      expect(recordedFailures.single, contains('token refresh failed'));
    },
  );

  test(
    'only the kept failures are written, not an ever-growing file',
    () async {
      for (var i = 0; i < failureLogLimit + 10; i++) {
        reportFailure(
          AppFailure(kind: AppFailureKind.unknown, debugMessage: 'failure $i'),
        );
      }
      await pendingFailureWrites;

      forgetRecordedFailuresInMemory();
      await loadRecordedFailures();

      expect(recordedFailures, hasLength(failureLogLimit));
    },
  );

  test('clearing forgets them on disk too, not just on screen', () async {
    reportFailure(
      const AppFailure(
        kind: AppFailureKind.unknown,
        debugMessage: 'something private',
      ),
    );
    await pendingFailureWrites;

    await clearRecordedFailures();
    await loadRecordedFailures();

    expect(
      recordedFailures,
      isEmpty,
      reason: 'a clear that leaves the file behind is a lie to the user',
    );
  });
}
