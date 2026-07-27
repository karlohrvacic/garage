import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/fuel/screens/fuel_log_screen.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

FuelEntry fill({
  required String id,
  required int odometerKm,
  bool missedFill = false,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 7, 24),
    odometerKm: odometerKm,
    volumeL: 43.4,
    pricePerL: 1.55,
    total: 67.27,
    fullTank: true,
    missedFill: missedFill,
    createdBy: 'u1',
  );
}

Future<void> pumpFuelLog(WidgetTester tester, List<FuelEntry> entries) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        rawFuelEntriesProvider('v1').overrideWith((ref) async => entries),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FuelLogScreen(vehicleId: 'v1'),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'a row without a computable economy shows the compact placeholder, '
      'not the long explanation that crushes the ListTile layout',
      (tester) async {
    // A single full-tank fill has no previous fill to compute a span from.
    await pumpFuelLog(tester, [fill(id: 'f1', odometerKm: 51140)]);
    await tester.pumpAndSettle();

    expect(
      find.text('Not enough full-tank fills to calculate'),
      findsNothing,
    );
    expect(find.text(UnitFormat.emptyValue), findsWidgets);
  });

  testWidgets('rows with a computable span still show their economy',
      (tester) async {
    await pumpFuelLog(tester, [
      fill(id: 'f1', odometerKm: 50310),
      fill(id: 'f2', odometerKm: 51140),
    ]);
    await tester.pumpAndSettle();

    expect(find.textContaining('l/100km'), findsWidgets);
  });
}
