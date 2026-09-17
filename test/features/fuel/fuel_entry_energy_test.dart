import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/theme/garage_tokens.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/stations/fuel_price_context.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/fuel/providers/pump_providers.dart';
import 'package:garage/features/fuel/screens/fuel_log_screen.dart';
import 'package:garage/features/fuel/widgets/fuel_entry_sheet.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/stations/providers/station_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

// A charge is kilowatt-hours whatever the household pours. The sheet used to
// convert whatever was typed as though it were litres, so in a garage that
// reads US gallons 50 kWh went into the database as 189.27, the log said
// "189.27 kWh", and the consumption came out 3.8 times too high. The rule is
// the entry's own fuel, falling back to the car's: a plug-in hybrid kept as
// petrol charges in kilowatt-hours too.

const _usGallons = UnitPreferences(
  distance: DistanceUnit.km,
  volume: VolumeUnit.usGallon,
  currencyCode: 'USD',
);

const _litresPerGallon = 3.785411784;

Vehicle _electric() => testVehicle('v1', fuelTypeKey: 'fuel_electric');

Vehicle _pluginHybrid({double? tankCapacityL}) => testVehicle(
  'v1',
  fuelTypeKey: 'fuel_petrol',
  secondaryFuelTypeKey: 'fuel_electric',
  tankCapacityL: tankCapacityL,
);

Vehicle _petrol() => testVehicle('v1', fuelTypeKey: 'fuel_petrol');

FuelEntry _entry(
  String id, {
  required int odometerKm,
  required double quantity,
  required double pricePerUnit,
  String? fuelTypeKey,
  String? station,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 8, 1).add(Duration(days: odometerKm - 50000)),
    odometerKm: odometerKm,
    volumeL: quantity,
    pricePerL: pricePerUnit,
    total: quantity * pricePerUnit,
    fullTank: true,
    missedFill: false,
    fuelTypeKey: fuelTypeKey,
    station: station,
    createdBy: 'u1',
  );
}

/// The car's fuel log in a US-gallon garage, with its fill-ups kept in
/// [repository] so a test can read back exactly what a save wrote.
Future<void> _pumpLog(
  WidgetTester tester,
  Vehicle vehicle,
  FakeFuelRepository repository, {
  Size surface = const Size(400, 1000),

  /// The car cannot be read, for the sheet that has to say so rather than
  /// guess what an entry's amount is in.
  bool carFails = false,
}) async {
  await pumpScreen(
    tester,
    const FuelLogScreen(vehicleId: 'v1'),
    preferences: _usGallons,
    vehicles: [vehicle],
    surface: surface,
    overrides: [
      fuelRepositoryProvider.overrideWithValue(repository),
      // The real one reads six entry providers, each of which would reach for
      // a Supabase client; the odometer guard is not what this is about.
      rawOdometerSamplesProvider('v1').overrideWith((ref) async => const []),
      stationAtThePumpProvider('v1').overrideWith((ref) async => null),
      stationsProvider.overrideWith((ref) async => const []),
      if (carFails)
        vehicleProvider('v1').overrideWith(
          (ref) async => throw const AppFailure(kind: AppFailureKind.network),
        ),
    ],
  );
  await tester.pumpAndSettle();
}

Finder _fields() => find.descendant(
  of: find.byType(FuelEntrySheet),
  matching: find.byType(TextField),
);

String _textIn(WidgetTester tester, int field) =>
    tester.widget<TextField>(_fields().at(field)).controller!.text;

const _odometer = 0;
const _quantity = 1;
const _price = 2;
const _total = 3;
const _station = 4;

Future<void> _openNew(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, int field, String value) async {
  await tester.enterText(_fields().at(field), value);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.descendant(
    of: find.byType(FuelEntrySheet),
    matching: find.widgetWithText(FilledButton, 'Save'),
  );
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String fuel) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.text(fuel),
    ),
  );
  await tester.pumpAndSettle();
}

bool _showsUnit(String unit) => find
    .descendant(of: find.byType(FuelEntrySheet), matching: find.text(unit))
    .evaluate()
    .isNotEmpty;

void main() {
  group('an electric car in a garage that pours gallons', () {
    testWidgets('stores the kilowatt-hours that were typed', (tester) async {
      final repository = FakeFuelRepository();
      await _pumpLog(tester, _electric(), repository);

      await _openNew(tester);
      await _type(tester, _odometer, '50300');
      await _type(tester, _quantity, '50');
      await _type(tester, _total, '15');
      await _save(tester);

      final saved = repository.entries.single;
      expect(saved.volumeL, 50);
      expect(saved.pricePerL, closeTo(0.30, 0.000001));
      expect(find.textContaining('50.00 kWh'), findsOneWidget);
    });

    testWidgets('stores a price per kilowatt-hour as typed', (tester) async {
      final repository = FakeFuelRepository();
      await _pumpLog(tester, _electric(), repository);

      await _openNew(tester);
      await _type(tester, _odometer, '50300');
      await _type(tester, _quantity, '50');
      await _type(tester, _price, '0.30');
      expect(_textIn(tester, _total), '15');
      await _save(tester);

      final saved = repository.entries.single;
      expect(saved.volumeL, 50);
      expect(saved.pricePerL, closeTo(0.30, 0.000001));
      expect(saved.total, 15);
    });

    testWidgets('reopens a charge as the kilowatt-hours it was', (
      tester,
    ) async {
      final repository = FakeFuelRepository(
        entries: [
          _entry('c1', odometerKm: 50300, quantity: 50, pricePerUnit: 0.3),
        ],
      );
      await _pumpLog(tester, _electric(), repository);

      expect(find.textContaining('50.00 kWh'), findsOneWidget);
      await tester.tap(find.textContaining('50.00 kWh'));
      await tester.pumpAndSettle();

      expect(_textIn(tester, _quantity), '50.00');
      expect(_textIn(tester, _price), '0.3');
      expect(_showsUnit('kWh'), isTrue);
      expect(_showsUnit(r'$/kWh'), isTrue);
      expect(_showsUnit('gal'), isFalse);
    });

    testWidgets('an edit saved untouched writes back what was there', (
      tester,
    ) async {
      final repository = FakeFuelRepository(
        entries: [
          _entry('c1', odometerKm: 50300, quantity: 50, pricePerUnit: 0.3),
        ],
      );
      await _pumpLog(tester, _electric(), repository);

      await tester.tap(find.textContaining('50.00 kWh'));
      await tester.pumpAndSettle();
      await _save(tester);

      final written = repository.updated.single;
      expect(written.volumeL, 50);
      expect(written.pricePerL, closeTo(0.3, 0.000001));
    });

    testWidgets('says so when the car cannot be read, rather than guess', (
      tester,
    ) async {
      // Which unit the amount is in is the car's to say. Without the car the
      // fields stay empty, and the sheet says why instead of sitting there.
      await _pumpLog(
        tester,
        _electric(),
        FakeFuelRepository(
          entries: [
            _entry('c1', odometerKm: 50300, quantity: 50, pricePerUnit: 0.3),
          ],
        ),
        carFails: true,
      );

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(_textIn(tester, _quantity), isEmpty);
      expect(
        find.descendant(
          of: find.byType(FuelEntrySheet),
          matching: find.textContaining('No connection'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers the last price per kilowatt-hour unconverted', (
      tester,
    ) async {
      final repository = FakeFuelRepository(
        entries: [
          _entry('c1', odometerKm: 50300, quantity: 50, pricePerUnit: 0.3),
        ],
      );
      await _pumpLog(tester, _electric(), repository);

      await _openNew(tester);

      expect(_textIn(tester, _price), '0.3');
    });
  });

  group('a plug-in hybrid kept as petrol', () {
    testWidgets('stores a charge unconverted and a fill converted', (
      tester,
    ) async {
      final repository = FakeFuelRepository();
      await _pumpLog(tester, _pluginHybrid(), repository);

      await _openNew(tester);
      await _choose(tester, 'Electric');
      await _type(tester, _odometer, '50300');
      await _type(tester, _quantity, '50');
      await _type(tester, _total, '15');
      await _save(tester);

      // Petrol is what the car mainly takes and is already chosen; a fill that
      // names no fuel is that one.
      await _openNew(tester);
      await _type(tester, _odometer, '50600');
      await _type(tester, _quantity, '10');
      await _type(tester, _price, '4');
      await _save(tester);

      final charge = repository.entries.firstWhere(
        (entry) => entry.fuelTypeKey == 'fuel_electric',
      );
      expect(charge.volumeL, 50);
      expect(charge.pricePerL, closeTo(0.30, 0.000001));

      final fill = repository.entries.firstWhere(
        (entry) => entry.fuelTypeKey == null,
      );
      expect(fill.volumeL, closeTo(10 * _litresPerGallon, 0.000001));
      expect(fill.pricePerL, closeTo(4 / _litresPerGallon, 0.000001));
    });

    testWidgets('names a charge in kilowatt-hours while it is typed', (
      tester,
    ) async {
      await _pumpLog(tester, _pluginHybrid(), FakeFuelRepository());

      await _openNew(tester);
      expect(find.text('Volume'), findsOneWidget);
      expect(_showsUnit('gal'), isTrue);

      await _choose(tester, 'Electric');

      expect(find.text('Charge (kWh)'), findsOneWidget);
      expect(_showsUnit('kWh'), isTrue);
      expect(_showsUnit(r'$/kWh'), isTrue);
      expect(_showsUnit('gal'), isFalse);
    });

    testWidgets('does not measure a charge against the petrol tank', (
      tester,
    ) async {
      await _pumpLog(
        tester,
        _pluginHybrid(tankCapacityL: 40),
        FakeFuelRepository(),
      );

      await _openNew(tester);
      await _choose(tester, 'Electric');
      await _type(tester, _quantity, '60');

      expect(find.textContaining('More than the tank holds'), findsNothing);
    });

    testWidgets('reads a charge in the log in kilowatt-hours', (tester) async {
      await _pumpLog(
        tester,
        _pluginHybrid(),
        FakeFuelRepository(
          entries: [
            _entry(
              'c1',
              odometerKm: 50300,
              quantity: 50,
              pricePerUnit: 0.3,
              fuelTypeKey: 'fuel_electric',
            ),
            _entry(
              'f1',
              odometerKm: 50600,
              quantity: 10 * _litresPerGallon,
              pricePerUnit: 4 / _litresPerGallon,
              fuelTypeKey: 'fuel_petrol',
            ),
          ],
        ),
      );

      expect(find.textContaining('50.00 kWh'), findsOneWidget);
      expect(find.textContaining('10.00 gal'), findsOneWidget);
    });

    testWidgets('reads each tank in what it burned', (tester) async {
      // Two full charges 300 km apart and two full tanks 500 km apart. The
      // charge is 16.7 kWh/100km; inverted as though it were litres it read
      // 14.1 mpg, and the two chains averaged together read 21.4.
      await _pumpLog(
        tester,
        _pluginHybrid(),
        FakeFuelRepository(
          entries: [
            for (final (id, km) in [('c1', 50000), ('c2', 50300)])
              _entry(
                id,
                odometerKm: km,
                quantity: 50,
                pricePerUnit: 0.3,
                fuelTypeKey: 'fuel_electric',
              ),
            for (final (id, km) in [('f1', 50400), ('f2', 50900)])
              _entry(
                id,
                odometerKm: km,
                quantity: 10 * _litresPerGallon,
                pricePerUnit: 4 / _litresPerGallon,
                fuelTypeKey: 'fuel_petrol',
              ),
          ],
        ),
      );

      expect(find.text('16.7 kWh/100km'), findsOneWidget);
      expect(find.text('14.1 mpg'), findsNothing);
      expect(find.text('31.1 mpg'), findsWidgets);
      expect(find.text('21.4 mpg'), findsNothing);
    });

    testWidgets('measures a charge against charges, not petrol tanks', (
      tester,
    ) async {
      // Four charges alike and four tanks alike. Against each other the
      // charges read "60% more than this car's usual", the tanks "35% less",
      // and both were coloured as the car's worst and best.
      await _pumpLog(
        tester,
        _pluginHybrid(),
        FakeFuelRepository(
          entries: [
            for (final km in [50000, 50300, 50600, 50900, 51200])
              _entry(
                'c$km',
                odometerKm: km,
                quantity: 50,
                pricePerUnit: 0.3,
                fuelTypeKey: 'fuel_electric',
              ),
            for (final km in [50050, 50550, 51050, 51550, 52050])
              _entry(
                'f$km',
                odometerKm: km,
                quantity: 10 * _litresPerGallon,
                pricePerUnit: 4 / _litresPerGallon,
                fuelTypeKey: 'fuel_petrol',
              ),
          ],
        ),
        surface: const Size(400, 6000),
      );

      expect(find.text('16.7 kWh/100km'), findsNWidgets(4));
      expect(find.textContaining("than this car's usual"), findsNothing);
      const tokens = GarageTokens.light;
      for (final figure in tester.widgetList<Text>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('16.7 kWh/100km'),
        ),
      )) {
        expect(
          figure.style?.color,
          isNot(anyOf(tokens.success, tokens.warn, tokens.danger)),
        );
      }
    });

    testWidgets('reopens a charge as the kilowatt-hours it was', (
      tester,
    ) async {
      await _pumpLog(
        tester,
        _pluginHybrid(),
        FakeFuelRepository(
          entries: [
            _entry(
              'c1',
              odometerKm: 50300,
              quantity: 50,
              pricePerUnit: 0.3,
              fuelTypeKey: 'fuel_electric',
            ),
          ],
        ),
      );

      await tester.tap(find.textContaining('50.00 kWh'));
      await tester.pumpAndSettle();

      expect(_textIn(tester, _quantity), '50.00');
      expect(_textIn(tester, _price), '0.3');
    });

    testWidgets('does not leave a petrol price guessed for a charge', (
      tester,
    ) async {
      // The guess is the last price paid for the fuel going in. Carried
      // across to a charge it would be a price per gallon read per
      // kilowatt-hour, and a total worked out from it.
      final repository = FakeFuelRepository(
        entries: [
          _entry(
            'c1',
            odometerKm: 50300,
            quantity: 50,
            pricePerUnit: 0.3,
            fuelTypeKey: 'fuel_electric',
          ),
          _entry(
            'f1',
            odometerKm: 50600,
            quantity: 10 * _litresPerGallon,
            pricePerUnit: 4 / _litresPerGallon,
            fuelTypeKey: 'fuel_petrol',
          ),
        ],
      );
      await _pumpLog(tester, _pluginHybrid(), repository);

      await _openNew(tester);
      expect(_textIn(tester, _price), '4');

      await _choose(tester, 'Electric');
      expect(_textIn(tester, _price), '0.3');

      await _choose(tester, 'Petrol');
      expect(_textIn(tester, _price), '4');
    });

    testWidgets('remembers where each fuel was last bought', (tester) async {
      // A charge at home and a tank at INA: the place remembered for one is
      // not a guess at where the other went in.
      final repository = FakeFuelRepository(
        entries: [
          _entry(
            'c1',
            odometerKm: 50300,
            quantity: 50,
            pricePerUnit: 0.3,
            fuelTypeKey: 'fuel_electric',
            station: 'Home',
          ),
          _entry(
            'f1',
            odometerKm: 50600,
            quantity: 10 * _litresPerGallon,
            pricePerUnit: 4 / _litresPerGallon,
            fuelTypeKey: 'fuel_petrol',
            station: 'INA',
          ),
        ],
      );
      await _pumpLog(tester, _pluginHybrid(), repository);

      await _openNew(tester);
      expect(_textIn(tester, _station), 'INA');

      await _choose(tester, 'Electric');
      expect(_textIn(tester, _station), 'Home');

      await _choose(tester, 'Petrol');
      expect(_textIn(tester, _station), 'INA');
    });
  });

  group('a petrol car in a garage that pours gallons', () {
    // The positive control: everything above must leave this exactly as it
    // was.
    testWidgets('still stores litres and a price per litre', (tester) async {
      final repository = FakeFuelRepository();
      await _pumpLog(tester, _petrol(), repository);

      await _openNew(tester);
      await _type(tester, _odometer, '50300');
      await _type(tester, _quantity, '10');
      await _type(tester, _total, '40');
      await _save(tester);

      final saved = repository.entries.single;
      expect(saved.volumeL, closeTo(10 * _litresPerGallon, 0.000001));
      expect(saved.pricePerL, closeTo(4 / _litresPerGallon, 0.000001));
      expect(find.textContaining('10.00 gal'), findsOneWidget);
    });

    testWidgets('and reopens it in gallons at a price per gallon', (
      tester,
    ) async {
      await _pumpLog(
        tester,
        _petrol(),
        FakeFuelRepository(
          entries: [
            _entry(
              'f1',
              odometerKm: 50300,
              quantity: 10 * _litresPerGallon,
              pricePerUnit: 4 / _litresPerGallon,
            ),
          ],
        ),
      );

      await tester.tap(find.textContaining('10.00 gal'));
      await tester.pumpAndSettle();

      expect(_textIn(tester, _quantity), '10.00');
      expect(_textIn(tester, _price), '4');
      expect(_showsUnit(r'$/gal'), isTrue);
    });

    testWidgets('says how much cheaper nearby was per gallon', (tester) async {
      // The snapshot is per litre, like every stored price. Ten cents a litre
      // printed as ten cents under a sheet that prices by the gallon read as
      // a quarter of what it was.
      await _pumpLog(
        tester,
        _petrol(),
        FakeFuelRepository(
          entries: [
            _entry(
              'f1',
              odometerKm: 50300,
              quantity: 40,
              pricePerUnit: 1.10,
            ).copyWith(
              priceContext: FuelPriceContext(
                station: 'Tifon',
                pricePerUnit: 1.00,
                distanceKm: 2,
                seenOn: DateTime.utc(2026, 8, 1),
              ),
            ),
          ],
        ),
      );

      expect(
        find.textContaining(r'$0.38 cheaper 2.0 km away, at Tifon'),
        findsOneWidget,
      );
    });

    testWidgets('offers the last price per gallon', (tester) async {
      await _pumpLog(
        tester,
        _petrol(),
        FakeFuelRepository(
          entries: [
            _entry(
              'f1',
              odometerKm: 50300,
              quantity: 10 * _litresPerGallon,
              pricePerUnit: 4 / _litresPerGallon,
            ),
          ],
        ),
      );

      await _openNew(tester);

      expect(_textIn(tester, _price), '4');
    });
  });
}
