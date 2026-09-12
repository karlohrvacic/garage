import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/core/widgets/discard_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/odometer_history.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/station_at_the_pump.dart';
import 'package:garage/features/fuel/providers/pump_providers.dart';
import 'package:garage/features/fuel/widgets/fuel_entry_sheet.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:garage/core/errors/app_failure.dart';
import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

import 'package:garage/core/sync/sync_providers.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/domain/entities/attachment.dart';
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

Vehicle car({
  double? tankCapacityL,
  String fuelTypeKey = 'fuel_diesel',
  String? secondaryFuelTypeKey,
}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: fuelTypeKey,
    secondaryFuelTypeKey: secondaryFuelTypeKey,
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

/// Says the row is already there, the way a landed-then-retried insert does.
class AlreadySavedFuelRepository extends FailingFuelRepository {
  AlreadySavedFuelRepository() : super(const []);

  final List<FuelEntry> attempted = [];

  @override
  Future<void> add(FuelEntry entry) async {
    attempted.add(entry);
    throw const AppFailure(kind: AppFailureKind.conflict);
  }
}

/// Refuses every write, the way a dead connection does.
class RefusingFuelRepository extends FailingFuelRepository {
  RefusingFuelRepository() : super(const []);

  @override
  Future<void> add(FuelEntry entry) async => throw Exception('no network');
}

Future<void> pumpSheet(
  WidgetTester tester, {
  PendingWriteStore? pendingWrites,
  List<FuelEntry> log = const [],
  FuelEntry? existing,
  Vehicle? vehicle,

  /// The garage's cars, when the test needs more than the one the sheet is
  /// for. Defaults to just [vehicle].
  List<Vehicle>? vehicles,
  FuelRepository? repository,
  PumpMatch? atThePump,

  /// Today's posted prices. Empty by default, which is the world every test
  /// that predates the posted-price prefill was written against.
  List<FuelStation> stations = const [],

  /// Readings from something other than a fill-up — a service, a bare
  /// odometer entry. Merged with [log], the way the app merges them, because
  /// the odometer guard is measured against every kind of reading and not
  /// just the fuel log.
  List<OdometerSample> otherReadings = const [],

  /// Behind a route that can pop, for tests that save: the sheet pops itself
  /// on success, and the home route cannot be popped.
  bool poppable = false,

  /// What is already attached, and what the file picker hands back.
  FakeAttachmentRepository? attachments,
  XFile? pickedFile,
  Locale? locale,
  double textScale = 1,
  Size? surface,
}) {
  if (surface != null) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = surface;
    addTearDown(tester.view.reset);
  }
  final sheet = FuelEntrySheet(vehicleId: 'v1', existing: existing);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The sheet asks the queue whether its entry is waiting to sync. The
        // real store is SharedPreferences, which hangs in a test with no mock
        // values and turns a save into a pumpAndSettle timeout.
        pendingWriteStoreProvider.overrideWithValue(
          pendingWrites ?? InMemoryPendingWriteStore(),
        ),
        if (repository != null)
          fuelRepositoryProvider.overrideWithValue(repository),
        attachmentRepositoryProvider.overrideWithValue(
          attachments ?? FakeAttachmentRepository(),
        ),
        filePickerProvider.overrideWithValue(() async => pickedFile),
        rawFuelEntriesProvider('v1').overrideWith((ref) async => log),
        // Overridden directly rather than left to derive: the real one reads
        // six entry providers, and a sheet test has no business standing all
        // six up to say what the odometer has been.
        rawOdometerSamplesProvider('v1').overrideWith(
          (ref) async => [
            for (final entry in log)
              OdometerSample(date: entry.date, km: entry.odometerKm),
            ...otherReadings,
          ],
        ),
        stationAtThePumpProvider('v1').overrideWith((ref) async => atThePump),
        // Any other car in the garage is not at a pump: the real provider
        // would go looking for a location.
        for (final other in vehicles ?? const <Vehicle>[])
          if (other.id != 'v1')
            stationAtThePumpProvider(
              other.id,
            ).overrideWith((ref) async => null),
        stationsProvider.overrideWith((ref) async => stations),
        allVehiclesProvider.overrideWith(
          (ref) async => vehicles ?? [vehicle ?? car()],
        ),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: poppable
              ? Navigator(
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => sheet),
                )
              : sheet,
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

    testWidgets('flags a fill-up below a reading that was not a fill-up', (
      tester,
    ) async {
      // The guard read the fuel log alone, so a household that logs services
      // or bare odometer readings and pays cash at the pump could type any
      // number here and be told nothing — which is exactly the household
      // odometer entries were added for.
      await pumpSheet(
        tester,
        otherReadings: [
          OdometerSample(date: DateTime.utc(2026, 6, 1), km: 50800),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '50250',
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

    testWidgets('so can one that has not been saved yet', (tester) async {
      // Was "cannot": the receipt is in the hand at the counter, and a
      // paperclip that appears only on a second visit was never found.
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      expect(find.text('Attachments'), findsOneWidget);
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
        find.textContaining('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(FuelEntrySheet), findsOneWidget);
    });

    testWidgets('the receipt goes with the entry', (tester) async {
      // `attachments.entry_id` carries no foreign key (decision 90), so
      // nothing in the database takes a receipt away when its entry goes —
      // and PRIVACY.md promises deleting an entry deletes its attachments.
      final attachments = FakeAttachmentRepository([
        Attachment(
          id: 'a1',
          vehicleId: 'v1',
          entryKind: AttachmentEntryKind.fuel,
          entryId: _log[1].id,
          storagePath: 'v1/a1-receipt.jpg',
          fileName: 'receipt.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1024,
          createdBy: 'u1',
          createdAt: DateTime.utc(2026, 7, 24),
        ),
      ]);
      await pumpSheet(
        tester,
        log: _log,
        existing: _log[1],
        repository: FakeFuelRepository(entries: _log),
        attachments: attachments,
        poppable: true,
      );
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(OutlinedButton, 'Delete');
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(attachments.stored, isEmpty);
      expect(attachments.calls, contains('deleteForEntry:fuel:${_log[1].id}'));
    });

    testWidgets('a sweep that fails does not undo the delete', (tester) async {
      // The entry is already gone by then. An error about a file the user
      // cannot see is about nothing they can act on, and holding the sheet
      // open would suggest the deletion had not happened.
      final attachments = FakeAttachmentRepository()..failSweep = true;
      final repository = FakeFuelRepository(entries: _log);
      await pumpSheet(
        tester,
        log: _log,
        existing: _log[1],
        repository: repository,
        attachments: attachments,
        poppable: true,
      );
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(OutlinedButton, 'Delete');
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleted, contains(_log[1].id));
      expect(find.byType(FuelEntrySheet), findsNothing);
    });
  });

  // The app already knows every Croatian station's position and today's posted
  // prices, and the driver's own position once they have granted it. Someone
  // standing at a pump typing what they just paid is typing something it could
  // have offered.
  group('standing at a station', () {
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

  group('the title says which it is', () {
    testWidgets('adding', (tester) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('Add fill-up'), findsOneWidget);
    });

    testWidgets('editing', (tester) async {
      await pumpSheet(tester, log: _log, existing: _log[1]);
      await tester.pumpAndSettle();

      expect(find.text('Edit fill-up'), findsOneWidget);
    });
  });

  // The pump match only fires for someone standing on a forecourt, which is
  // the wrong moment for most people: a fill-up is usually logged at home,
  // where the sheet used to fall back to the price of the last fill-up — a
  // number that can be weeks stale.
  group("today's price at the station you last used", () {
    FuelStation priced(String name, double price) {
      return FuelStation(
        id: name.hashCode,
        name: name,
        brand: 'INA',
        address: null,
        place: 'Zagreb',
        lat: 45.8,
        lng: 15.98,
        prices: [
          StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: price),
        ],
      );
    }

    testWidgets('is offered instead of what was paid there last time', (
      tester,
    ) async {
      await pumpSheet(tester, log: _log, stations: [priced('INA', 1.66)]);
      await tester.pumpAndSettle();

      expect(find.text('1.66'), findsOneWidget);
      expect(
        find.text('1.55'),
        findsNothing,
        reason: 'the last fill-up price is what this feature exists to replace',
      );
    });

    testWidgets('leaves the station itself as the last fill-up recorded it', (
      tester,
    ) async {
      await pumpSheet(tester, log: _log, stations: [priced('INA', 1.66)]);
      await tester.pumpAndSettle();

      expect(find.text('INA'), findsWidgets);
    });

    testWidgets('falls back to the last price when that station is unpriced', (
      tester,
    ) async {
      await pumpSheet(tester, log: _log, stations: [priced('Shell', 1.66)]);
      await tester.pumpAndSettle();

      expect(find.text('1.55'), findsOneWidget);
    });

    testWidgets('falls back when the dataset has no stations at all', (
      tester,
    ) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      expect(find.text('1.55'), findsOneWidget);
    });

    // The bug this guards against: quietly moving a recorded amount to today's
    // price would rewrite what was actually paid.
    testWidgets('never touches an entry being edited', (tester) async {
      await pumpSheet(
        tester,
        log: _log,
        existing: fill(
          id: 'f3',
          odometerKm: 51600,
          date: DateTime.utc(2026, 7, 1),
          station: 'INA',
          pricePerL: 1.55,
        ),
        stations: [priced('INA', 1.66)],
      );
      await tester.pumpAndSettle();

      expect(find.text('1.55'), findsOneWidget);
      expect(find.text('1.66'), findsNothing);
    });

    // Standing at a pump is better evidence than a remembered name.
    testWidgets('gives way to the station actually being stood at', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        log: _log,
        stations: [priced('INA', 1.66)],
        atThePump: PumpMatch(
          station: priced('Zagreb-Zapad', 1.49),
          pricePerUnit: 1.49,
          distanceKm: 0.03,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.49'), findsOneWidget);
    });
  });

  testWidgets('every number says its unit', (tester) async {
    // "Količina" under "Kilometraža" with nothing beside the box was read as
    // "litres, probably".
    await pumpSheet(tester);
    await tester.pumpAndSettle();

    expect(find.text('km'), findsOneWidget);
    expect(find.text('l'), findsOneWidget);
    expect(find.text('€/l'), findsOneWidget);
    expect(find.text('€'), findsOneWidget);
  });

  group('a prefilled price', () {
    testWidgets('is selected on focus, so typing replaces it', (tester) async {
      // With the caret at its end, "1.47" over "1.45" gave "1.451.47" and a
      // blank total.
      await pumpSheet(
        tester,
        log: [
          fill(
            id: 'f1',
            odometerKm: 45000,
            date: DateTime.utc(2026, 8, 1),
            pricePerL: 1.45,
          ),
        ],
      );
      await tester.pumpAndSettle();
      final price = find.byType(TextField).at(_priceField);
      expect(tester.widget<TextField>(price).controller!.text, '1.45');

      await tester.tap(price);
      await tester.pump();

      final selection = tester.widget<TextField>(price).controller!.selection;
      expect(selection.start, 0);
      expect(selection.end, 4);
    });

    testWidgets('a malformed amount says so instead of blanking the total', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).at(_priceField),
        '1.451.47',
      );
      await tester.pump();

      expect(find.text('Not a number'), findsOneWidget);
    });
  });

  group('the second fill-up of the day', () {
    testWidgets('is compared against the first, not the baseline', (
      tester,
    ) async {
      final now = DateTime.now();
      await pumpSheet(
        tester,
        log: [
          fill(
            id: 'f1',
            odometerKm: 145620,
            date: DateTime.utc(now.year, now.month, now.day),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Earlier today: 145,620 km'), findsOneWidget);
      expect(find.textContaining('Last reading'), findsNothing);
    });
  });

  group('a save retried after a timeout', () {
    testWidgets('carries the same id and lands once', (tester) async {
      // A timed-out insert cannot be cancelled. With the id chosen on the
      // device, the retry is the same row, and the conflict it raises means
      // "already there", which is a success.
      final repository = AlreadySavedFuelRepository();
      await pumpSheet(tester, repository: repository, poppable: true);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '45200',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '38.4');
      await tester.enterText(find.byType(TextField).at(_priceField), '1.45');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.attempted.single.id, isNotEmpty);
      expect(find.textContaining('Saved'), findsOneWidget);
      expect(find.textContaining('Something went wrong'), findsNothing);
    });
  });

  group('when the save fails', () {
    testWidgets('the line says the entry is still here', (tester) async {
      await pumpSheet(tester, repository: RefusingFuelRepository());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '45200',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '38.4');
      await tester.enterText(find.byType(TextField).at(_priceField), '1.45');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.textContaining('Your entry is still here.'), findsOneWidget);
    });
  });

  group('the vehicle it is for', () {
    testWidgets('is the first row, and with one car it stays put', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      final row = find.byKey(const Key('sheet-vehicle'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('Golf')), findsOne);
      expect(find.byIcon(Icons.unfold_more), findsNothing);
    });

    testWidgets('with two cars a new entry can be moved to the other', (
      tester,
    ) async {
      // The sheet never said which car the + button had picked; with two,
      // the wrong-car fill-up was one tap from the dashboard.
      final repository = FakeFuelRepository();
      await pumpSheet(
        tester,
        vehicles: [
          car(),
          testVehicle('v2', nickname: 'Passat'),
        ],
        repository: repository,
        poppable: true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sheet-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passat').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('sheet-vehicle')),
          matching: find.text('Passat'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '50500',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '30');
      await tester.enterText(find.byType(TextField).at(_priceField), '1.5');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.entries.single.vehicleId, 'v2');
    });

    testWidgets('the pump it stood at goes with the first car', (tester) async {
      // The first car's pump match is a petrol pump; under the second car's
      // diesel fill-up it would name the wrong pump and the wrong price.
      await pumpSheet(
        tester,
        vehicles: [
          car(),
          testVehicle('v2', nickname: 'Passat'),
        ],
        repository: FakeFuelRepository(),
        atThePump: pump(),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Zagreb-Zapad'), findsWidgets);

      await tester.tap(find.byKey(const Key('sheet-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passat').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Zagreb-Zapad'), findsNothing);
    });
  });

  group('saving says so', () {
    Future<void> type(WidgetTester tester, int field, String value) async {
      await tester.enterText(find.byType(TextField).at(field), value);
      await tester.pump();
    }

    testWidgets('the first full tank says consumption needs one more', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        repository: FailingFuelRepository([]),
        poppable: true,
      );
      await tester.pumpAndSettle();

      await type(tester, _odometerField, '45200');
      await type(tester, _volumeField, '38.4');
      await type(tester, _priceField, '1.45');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('Saved, €55.68. One more full tank and consumption appears.'),
        findsOneWidget,
      );
    });

    testWidgets('counts full tanks per fuel on a bi-fuel car', (tester) async {
      // Consumption is per fuel. A petrol full tank in the log does not make
      // the first LPG full tank the second one.
      await pumpSheet(
        tester,
        vehicle: car(
          fuelTypeKey: 'fuel_petrol',
          secondaryFuelTypeKey: 'fuel_lpg',
        ),
        log: [
          fill(
            id: 'f1',
            odometerKm: 45000,
            date: DateTime.utc(2026, 8, 1),
            pricePerL: 1.5,
          ),
        ],
        repository: FailingFuelRepository([]),
        poppable: true,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('LPG'));
      await tester.pumpAndSettle();
      await type(tester, _odometerField, '45200');
      await type(tester, _volumeField, '38.4');
      await type(tester, _priceField, '1.45');
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('Saved, €55.68. One more full tank and consumption appears.'),
        findsOneWidget,
      );
    });
  });

  group('a receipt on an entry that is not saved yet', () {
    testWidgets('the sheet offers to attach one straight away', (tester) async {
      // Receipts were the least findable thing in the app: the paperclip
      // appeared only on the second visit to an entry, so nobody found it.
      await pumpSheet(tester);
      await tester.pumpAndSettle();

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      expect(add, findsOneWidget);
      expect(find.textContaining('Save the entry first'), findsNothing);
    });

    testWidgets('a file attached and then abandoned is not left behind', (
      tester,
    ) async {
      // The entry's id exists before the entry does, so the upload can go
      // ahead — but a sheet closed without saving must not leave a receipt
      // hanging off an entry nobody created.
      final attachments = FakeAttachmentRepository();
      await pumpSheet(
        tester,
        attachments: attachments,
        pickedFile: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await tester.pumpAndSettle();

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(attachments.stored, hasLength(1));

      // Closing the sheet without saving takes the widget down.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(attachments.stored, isEmpty);
    });

    testWidgets('a saved fill-up keeps what was attached to it', (
      tester,
    ) async {
      // The other half of the rule, and the one whose failure loses real
      // data: once the entry exists, closing the sheet must leave the
      // receipt alone.
      final attachments = FakeAttachmentRepository();
      await pumpSheet(
        tester,
        repository: FakeFuelRepository(),
        attachments: attachments,
        pickedFile: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
        poppable: true,
      );
      await tester.pumpAndSettle();

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '50500',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '30');
      await tester.enterText(find.byType(TextField).at(_priceField), '1.5');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(attachments.stored, hasLength(1));
    });

    testWidgets('the car is locked once a receipt is on it, and says why', (
      tester,
    ) async {
      // The file carries the car's id, and that column follows the car
      // through a deletion or a transfer. A row that simply stopped
      // responding would read as broken, so it says what to do about it.
      await pumpSheet(
        tester,
        vehicles: [
          car(),
          testVehicle('v2', nickname: 'Passat'),
        ],
        repository: FakeFuelRepository(),
        attachments: FakeAttachmentRepository(),
        pickedFile: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.unfold_more), findsNothing);
      expect(
        find.textContaining('Remove the attachment to move this'),
        findsOneWidget,
      );
    });

    testWidgets('a receipt makes the sheet worth asking about', (tester) async {
      // Dismissing by tapping outside used to take the upload with it: the
      // guard counted typing only, and nothing had been typed.
      await pumpSheet(
        tester,
        attachments: FakeAttachmentRepository(),
        pickedFile: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'receipt.jpg',
          mimeType: 'image/jpeg',
        ),
        poppable: true,
      );
      await tester.pumpAndSettle();

      final add = find.byTooltip('Attach a receipt or document');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      final guard = tester.widget<DiscardGuard>(find.byType(DiscardGuard));
      expect(guard.alsoDirty!(), isTrue);
    });
  });

  group('a fill-up that cannot describe a journey', () {
    testWidgets('says what it works out at', (tester) async {
      // The classic transposed digit: 40 litres over 20 km. Both fields pass
      // their own checks and only the pair of them is nonsense.
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '${_log.last.odometerKm + 20}',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '40');
      await tester.pumpAndSettle();

      expect(find.textContaining('That works out at'), findsOneWidget);
    });

    testWidgets('and stays quiet about an ordinary one', (tester) async {
      await pumpSheet(tester, log: _log);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '${_log.last.odometerKm + 500}',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '40');
      await tester.pumpAndSettle();

      expect(find.textContaining('That works out at'), findsNothing);
    });

    testWidgets('does not refuse the save', (tester) async {
      // A jerrycan, a fill after a tow, a fill-up somebody forgot to log:
      // all real, and the household is the one who knows which this is.
      final repository = FakeFuelRepository();
      await pumpSheet(
        tester,
        log: _log,
        repository: repository,
        poppable: true,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(_odometerField),
        '${_log.last.odometerKm + 20}',
      );
      await tester.enterText(find.byType(TextField).at(_volumeField), '40');
      await tester.enterText(find.byType(TextField).at(_priceField), '1.5');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.entries, hasLength(1));
    });
  });

  testWidgets('in Croatian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    // The most-used sheet in the app: nine labelled fields, several with a
    // unit beside the value.
    await pumpSheet(
      tester,
      log: _log,
      existing: _log[1],
      repository: FakeFuelRepository(entries: _log),
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 3200),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('in Italian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    // The most-used sheet in the app: nine labelled fields, several with a
    // unit beside the value.
    await pumpSheet(
      tester,
      log: _log,
      existing: _log[1],
      repository: FakeFuelRepository(entries: _log),
      locale: const Locale('it'),
      textScale: 1.5,
      surface: const Size(320, 3200),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
