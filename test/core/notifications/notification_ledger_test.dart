import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final nine = DateTime(2026, 9, 21, 9);

  test(
    'a notice has fired once the moment it was set for has passed',
    () async {
      const ledger = PrefsNotificationLedger();
      await ledger.remember(scheduled: {'oil|7d': nine}, fired: const {});

      expect(await ledger.firedBy(DateTime(2026, 9, 21, 8)), isEmpty);
      expect(await ledger.firedBy(DateTime(2026, 9, 21, 10)), {'oil|7d'});
    },
  );

  test('and stays fired after the next plan leaves it out', () async {
    const ledger = PrefsNotificationLedger();
    await ledger.remember(scheduled: {'oil|7d': nine}, fired: const {});
    final fired = await ledger.firedBy(DateTime(2026, 9, 22));
    await ledger.remember(scheduled: const {}, fired: fired);

    expect(await ledger.firedBy(DateTime(2026, 9, 23)), {'oil|7d'});
  });

  test('forgets a cycle it is not told to keep', () async {
    // A serviced reminder starts a new cycle with a new key; the old one is
    // never planned again and is not worth carrying forever.
    const ledger = PrefsNotificationLedger();
    await ledger.remember(scheduled: const {}, fired: {'oil|7d'});
    await ledger.remember(scheduled: const {}, fired: const {});

    expect(await ledger.firedBy(DateTime(2026, 9, 23)), isEmpty);
  });
}
