import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/retry.dart';
import 'package:http/http.dart' as http;

/// Records how long each retry waited, without actually waiting.
class FakeClock {
  final List<Duration> slept = [];

  Future<void> call(Duration duration) async => slept.add(duration);
}

void main() {
  test('a call that works is made once', () async {
    var calls = 0;

    final result = await retryOnTransportFailure(() async {
      calls++;
      return 'done';
    }, sleep: FakeClock().call);

    expect(result, 'done');
    expect(calls, 1);
  });

  test('a transport failure is tried again on a fresh connection', () async {
    // The case this exists for: a TLS record that fails its integrity check
    // mid-upload. Nothing was refused; the connection went wrong in transit.
    var calls = 0;

    final result = await retryOnTransportFailure(() async {
      calls++;
      if (calls == 1) {
        throw http.ClientException(
          'SSLV3_ALERT_BAD_RECORD_MAC(tls_record.cc:486) error 268436476',
        );
      }
      return 'landed';
    }, sleep: FakeClock().call);

    expect(result, 'landed');
    expect(calls, 2);
  });

  test('it gives up rather than trying forever', () async {
    var calls = 0;

    await expectLater(
      retryOnTransportFailure(
        () async {
          calls++;
          throw const SocketException('down');
        },
        attempts: 3,
        sleep: FakeClock().call,
      ),
      throwsA(isA<SocketException>()),
    );

    expect(calls, 3);
  });

  test('a decision the server made is not retried', () async {
    // Repeating a refusal wastes the user's time and battery to be told the
    // same thing. Only failures below HTTP are worth another attempt.
    var calls = 0;

    await expectLater(
      retryOnTransportFailure(() async {
        calls++;
        throw const AppFailure(kind: AppFailureKind.permission);
      }, sleep: FakeClock().call),
      throwsA(isA<AppFailure>()),
    );

    expect(calls, 1, reason: 'a permission error will not improve on retry');
  });

  test('the original error is what escapes, not a wrapper', () async {
    // The failure log records the cause; replacing it with something of our
    // own would lose the one line that says what actually went wrong.
    await expectLater(
      retryOnTransportFailure(
        () async => throw const SocketException('the real cause'),
        attempts: 2,
        sleep: FakeClock().call,
      ),
      throwsA(
        isA<SocketException>().having(
          (e) => e.message,
          'message',
          'the real cause',
        ),
      ),
    );
  });

  test('waits get longer, but not exponentially', () async {
    final clock = FakeClock();

    await expectLater(
      retryOnTransportFailure(
        () async => throw const SocketException('down'),
        attempts: 3,
        delay: const Duration(milliseconds: 100),
        sleep: clock.call,
      ),
      throwsA(isA<SocketException>()),
    );

    // Two waits for three attempts, and the last is not long enough to read
    // as a hang.
    expect(clock.slept, const [
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
    ]);
  });
}
