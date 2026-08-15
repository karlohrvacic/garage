import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
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

void main() {
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
}
