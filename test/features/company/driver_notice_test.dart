import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/features/company/providers/driver_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the notice is shown until dismissed, on this device', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(driverNoticeSeenProvider.future), isFalse);

    await container.read(driverNoticeSeenProvider.notifier).markSeen();

    expect(await container.read(driverNoticeSeenProvider.future), isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'company.driver_notice.seen',
      ),
      isTrue,
    );
  });

  test('a device that already showed it says so from the first read', () async {
    SharedPreferences.setMockInitialValues({
      'company.driver_notice.seen': true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(driverNoticeSeenProvider.future), isTrue);
  });

  test(
    'a store it cannot read is recorded, and answers with the error',
    () async {
      // Something else wrote under the key: the read throws rather than
      // guessing, and the cause goes to the diagnostics log.
      await clearRecordedFailures();
      SharedPreferences.setMockInitialValues({
        'company.driver_notice.seen': 'yes',
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(driverNoticeSeenProvider.future),
        throwsA(isA<TypeError>()),
      );
      expect(recordedFailures.single, contains('bool'));
    },
  );
}
