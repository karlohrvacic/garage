import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/station_at_the_pump.dart';
import 'package:garage/features/fuel/providers/pump_providers.dart';
import 'package:garage/features/fuel/widgets/fuel_entry_sheet.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../attachments/attachment_providers_test.dart'
    show FakeAttachmentRepository;

FuelEntry fill({
  required String id,
  required int odometerKm,
  required DateTime date,
  String? station,
  double? pricePerL,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    odometerKm: odometerKm,
    volumeL: 40,
    pricePerL: pricePerL,
    total: pricePerL == null ? null : pricePerL * 40,
    fullTank: true,
    missedFill: false,
    station: station,
    createdBy: 'u1',
  );
}

Vehicle car({double? tankCapacityL, String fuelTypeKey = 'fuel_diesel'}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: fuelTypeKey,
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    tankCapacityL: tankCapacityL,
  );
}

final _log = [
  fill(id: 'f1', odometerKm: 50000, date: DateTime.utc(2026, 5, 1)),
  fill(
    id: 'f2',
    odometerKm: 50800,
    date: DateTime.utc(2026, 6, 1),
    station: 'Shell',
    pricePerL: 1.4,
  ),
  fill(
    id: 'f3',
    odometerKm: 51600,
    date: DateTime.utc(2026, 7, 1),
    station: 'INA',
    pricePerL: 1.55,
  ),
];

/// A repository whose deletes always fail, for the sheet's failure path.
class FailingFuelRepository implements FuelRepository {
  FailingFuelRepository(this.entries);

  final List<FuelEntry> entries;

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(FuelEntry entry) async {}

  @override
  Future<void> update(FuelEntry entry) async {}

  @override
  Future<void> delete(String id) async => throw Exception('nope');
}

Future<void> pumpSheet(
  WidgetTester tester, {
  List<FuelEntry> log = const [],
  FuelEntry? existing,
  Vehicle? vehicle,
  FuelRepository? repository,
  PumpMatch? atThePump,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          fuelRepositoryProvider.overrideWithValue(repository),
        attachmentRepositoryProvider.overrideWithValue(
          FakeAttachmentRepository(),
        ),
        rawFuelEntriesProvider('v1').overrideWith((ref) async => log),
        stationAtThePumpProvider('v1').overrideWith((ref) async => atThePump),
        allVehiclesProvider.overrideWith((ref) async => [vehicle ?? car()]),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FuelEntrySheet(vehicleId: 'v1', existing: existing),
        ),
      ),
    ),
  );
}

/// Field order in the sheet, for tests that type into one.
const _odometerField = 0;
const _volumeField = 1;
const _priceField = 2;
const _totalField = 3;

void main() {
  group('the third amount, worked out as you type', () {
    // The arithmetic was already here and only ran on save, so the receipt in
    // your hand said 60.75 and the sheet said nothing until you committed it.
    Future<void> type(WidgetTester tester, int field, String value) async {
      await tester.enterText(find.byType(TextField).at(field), value);
      await tester.pumpAndSettle();
    }

    String textIn(WidgetTester tester, int field) => tester
        .widget<TextField>(find.byType(TextField).at(field))
        .controller!
        .text;

    testWidgets('volume and price give the total', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _volumeField, '45');
      await type(tester, _priceField, '1.35');

      expect(textIn(tester, _totalField), '60.75');
    });

    testWidgets('volume and total give the price', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _volumeField, '45');
      await type(tester, _totalField, '60.75');

      expect(textIn(tester, _priceField), '1.35');
    });

    testWidgets('price and total give the volume', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _priceField, '1.35');
      await type(tester, _totalField, '60.75');

      expect(textIn(tester, _volumeField), '45');
    });

    testWidgets('changing an input moves the answer with it', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _volumeField, '45');
      await type(tester, _priceField, '1.35');
      await type(tester, _priceField, '1.50');

      expect(textIn(tester, _totalField), '67.5');
    });

    testWidgets('what you typed yourself is never overwritten', (tester) async {
      // The pump rounded, or the receipt has a discount on it. Their number
      // wins over ours.
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _volumeField, '45');
      await type(tester, _totalField, '60');
      await type(tester, _priceField, '1.35');

      expect(textIn(tester, _totalField), '60');
    });

    testWidgets('clearing an input clears the answer with it', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _volumeField, '45');
      await type(tester, _priceField, '1.35');
      await type(tester, _volumeField, '');

      expect(textIn(tester, _totalField), isEmpty);
    });

    testWidgets('a price of nothing does not divide by it', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      await type(tester, _priceField, '0');
      await type(tester, _totalField, '60');

      expect(textIn(tester, _volumeField), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('deriveMissingValue', () {
    test('fills in the total from volume and price', () {
      final result = deriveMissingValue(volume: '40', price: '1.5', total: '');

      expect(result.total, closeTo(60, 0.0001));
      expect(result.isComplete, isTrue);
    });

    test('fills in the price from volume and total', () {
      final result = deriveMissingValue(volume: '40', price: '', total: '60');

      expect(result.pricePerUnit, closeTo(1.5, 0.0001));
    });

    test('fills in the volume from price and total', () {
      final result = deriveMissingValue(volume: '', price: '1.5', total: '60');

      expect(result.volume, closeTo(40, 0.0001));
    });

    test('is incomplete with only one value', () {
      final result = deriveMissingValue(volume: '40', price: '', total: '');

      expect(result.isComplete, isFalse);
    });

    test('keeps all three when the user typed all three', () {
      final result = deriveMissingValue(
        volume: '40',
        price: '1.5',
        total: '61',
      );

      expect(result.total, closeTo(61, 0.0001));
      expect(result.isComplete, isTrue);
    });

    test('accepts a comma decimal separator', () {
      final result = deriveMissingValue(
        volume: '40,5',
        price: '1,5',
        total: '',
      );

      expect(result.volume, closeTo(40.5, 0.0001));
    });
  });

  group('the odometer guard', () {
    testWidgets('leaves an edited older fill-up alone', (tester) async {
      await pumpSheet(tester, log: _log, existing: _log[1]);
      await tester.pumpAndSettle();

      expect(find.textContaining('Lower than the previous'), findsNothing);
      expect(find.textContaining('Higher than the next'), findsNothing);
    });

    testWidgets('still flags a new fill-up below the newest reading', (
      tester,
    ) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '50500',
      );
      await tester.pump();

      expect(find.textContaining('Lower than the previous'), findsOneWidget);
    });

    testWidgets('flags an edit pushed past the following fill-up', (
      tester,
    ) async {
      await pumpSheet(tester, log: _log, existing: _log[1]);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '52000',
      );
      await tester.pump();

      expect(find.textContaining('Higher than the next'), findsOneWidget);
    });

    testWidgets('shows the last reading while adding', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      expect(find.textContaining('Last reading:'), findsOneWidget);
      expect(find.textContaining('51,600 km'), findsOneWidget);
    });
  });

  group('the tank capacity guard', () {
    testWidgets('flags a fill bigger than the tank', (tester) async {
      await pumpSheet(tester, log: _log, vehicle: car(tankCapacityL: 45));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(_volumeField), '60');
      await tester.pump();

      expect(find.textContaining('More than the tank holds'), findsOneWidget);
    });

    testWidgets('says nothing when the tank fits the fill', (tester) async {
      await pumpSheet(tester, log: _log, vehicle: car(tankCapacityL: 65));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(_volumeField), '60');
      await tester.pump();

      expect(find.textContaining('More than the tank holds'), findsNothing);
    });

    testWidgets('says nothing when no capacity is known', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(_volumeField), '600');
      await tester.pump();

      expect(find.textContaining('More than the tank holds'), findsNothing);
    });
  });

  group('a new fill-up', () {
    testWidgets('starts from the newest entry, not the oldest', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      expect(find.text('INA'), findsWidgets);
      expect(find.text('1.55'), findsOneWidget);
    });

    testWidgets('offers every station the household has used', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      final arrow = find.byIcon(Icons.arrow_drop_down).first;
      await tester.ensureVisible(arrow);
      await tester.pumpAndSettle();
      await tester.tap(arrow);
      await tester.pumpAndSettle();

      expect(find.text('Shell'), findsWidgets);
    });
  });

  group('an electric vehicle', () {
    testWidgets('logs a charge in kWh, not litres', (tester) async {
      await pumpSheet(
        tester,
        log: _log,
        vehicle: car(fuelTypeKey: 'fuel_electric'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Charge (kWh)'), findsOneWidget);
      expect(find.text('Volume'), findsNothing);
    });

    testWidgets('a petrol vehicle still logs volume', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('Charge (kWh)'), findsNothing);
    });

    testWidgets('has no tank to overfill', (tester) async {
      await pumpSheet(
        tester,
        log: _log,
        vehicle: car(fuelTypeKey: 'fuel_electric', tankCapacityL: 45),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(_volumeField), '60');
      await tester.pump();

      expect(find.textContaining('More than the tank holds'), findsNothing);
    });
  });

  group('attachments', () {
    testWidgets('an existing fill-up can carry receipts', (tester) async {
      await pumpSheet(tester, log: _log, existing: _log[1]);
      await tester.pumpAndSettle();

      expect(find.text('Attachments'), findsOneWidget);
    });

    testWidgets('a fill-up that does not exist yet cannot', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      expect(find.text('Attachments'), findsNothing);
    });
  });

  group('deleting an entry', () {
    testWidgets('reports a refused delete instead of throwing', (tester) async {
      await pumpSheet(
        tester,
        log: _log,
        existing: _log[1],
        repository: FailingFuelRepository(_log),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(OutlinedButton, 'Delete');
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(FuelEntrySheet), findsOneWidget);
    });
  });

  // The app already knows every Croatian station's position and today's posted
  // prices, and the driver's own position once they have granted it. Someone
  // standing at a pump typing what they just paid is typing something it could
  // have offered.
  group('standing at a station', () {
    PumpMatch pump({double price = 1.54, String name = 'Zagreb-Zapad'}) {
      return PumpMatch(
        station: FuelStation(
          id: 1,
          name: name,
          brand: 'INA',
          address: 'Ilica 1',
          place: 'Zagreb',
          lat: 45.8,
          lng: 15.98,
          prices: [
            StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: price),
          ],
        ),
        pricePerUnit: price,
        distanceKm: 0.03,
      );
    }

    testWidgets('the station and its price are filled in', (tester) async {
      await pumpSheet(tester, atThePump: pump());
      await tester.pumpAndSettle();

      expect(find.text('1.54'), findsOneWidget);
      expect(find.textContaining('Zagreb-Zapad'), findsWidgets);
    });

    // Offered, not imposed: the posted price is the headline one, and a
    // discount card or a different grade means the driver paid something else.
    testWidgets('and can be typed over', (tester) async {
      await pumpSheet(tester, atThePump: pump());
      await tester.pumpAndSettle();

      final price = find.byType(TextField).at(2);
      await tester.enterText(price, '1.41');
      await tester.pumpAndSettle();

      expect(find.text('1.41'), findsOneWidget);
      expect(find.text('1.54'), findsNothing);
    });

    testWidgets('nothing is filled in when there is no station', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Zagreb-Zapad'), findsNothing);
    });

    // Editing an old fill-up is not standing at a pump: overwriting what was
    // paid months ago with today's price would corrupt the record.
    testWidgets('an existing entry is never overwritten by it', (tester) async {
      await pumpSheet(tester, log: _log, existing: _log[1], atThePump: pump());
      await tester.pumpAndSettle();

      expect(find.text('1.54'), findsNothing);
    });
  });
}
