import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_scheduler.dart';
import 'package:garage/domain/maintenance/winter_tyre_period.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:garage/l10n/app_localizations_hr.dart';

ScheduledReminder reminder({
  List<String> keys = const ['service_tire_swap_seasonal'],
}) {
  return ScheduledReminder(
    id: 1,
    when: DateTime(2026, 10, 16, 9),
    serviceTypeKeys: keys,
    vehicleId: 'v1',
    leadDays: 30,
  );
}

SeasonalSwap swap(SwapDirection direction) =>
    SeasonalSwap(date: DateTime.utc(2026, 11, 15), direction: direction);

void main() {
  final en = AppLocalizationsEn();
  final hr = AppLocalizationsHr();

  // "Seasonal tyre swap" tells a driver a swap is due and not which way it
  // goes, which is the only part they act on — the tyres to dig out of the
  // cellar are winter ones in November and summer ones in April.
  group('what a seasonal swap notification is called', () {
    test('going into winter, it says which tyres to fit', () {
      expect(
        seasonalSwapTitle(en, reminder(), swap(SwapDirection.toWinter)),
        'Fit winter tyres',
      );
    });

    test('coming out of winter, it says the other thing', () {
      expect(
        seasonalSwapTitle(en, reminder(), swap(SwapDirection.toSummer)),
        'Back to summer tyres',
      );
    });

    test('Croatian says it in Croatian', () {
      expect(
        seasonalSwapTitle(hr, reminder(), swap(SwapDirection.toWinter)),
        'Stavite zimske gume',
      );
    });

    test('a country with no window keeps the generic service name', () {
      expect(seasonalSwapTitle(en, reminder(), null), isNull);
    });

    test('another kind of reminder is not renamed', () {
      expect(
        seasonalSwapTitle(
          en,
          reminder(keys: const ['service_oil_change']),
          swap(SwapDirection.toWinter),
        ),
        isNull,
      );
    });

    test('a bundle keeps its own title', () {
      // A swap bundled with an oil change is one visit covering two things,
      // and calling that notification "Fit winter tyres" would hide the other.
      expect(
        seasonalSwapTitle(
          en,
          reminder(
            keys: const ['service_tire_swap_seasonal', 'service_oil_change'],
          ),
          swap(SwapDirection.toWinter),
        ),
        isNull,
      );
    });
  });
}
