import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/features/vehicles/data/vin_decoder.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicle_edit_screen.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:typed_data';

import 'vehicle_photo_repository_test.dart' show FakeVehiclePhotoRepository;

class RecordingVehicleRepository implements VehicleRepository {
  RecordingVehicleRepository(this.vehicles);

  final List<Vehicle> vehicles;
  Vehicle? updated;

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async => vehicles;

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    updated = vehicle;
    return vehicle;
  }

  @override
  Future<void> update(Vehicle vehicle) async => updated = vehicle;

  @override
  Future<void> setArchived(String id, bool archived) async {}

  @override
  Future<void> deleteAllForHousehold(String householdId) async {}

  @override
  Future<String> offerTransfer(String vehicleId) async => 'TRANSFER';

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async => 'v1';
}

Vehicle car({double? tankCapacityL}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    tankCapacityL: tankCapacityL,
  );
}

const _metric = UnitPreferences(
  distance: DistanceUnit.km,
  volume: VolumeUnit.liter,
  currencyCode: 'EUR',
);
const _imperial = UnitPreferences(
  distance: DistanceUnit.mi,
  volume: VolumeUnit.usGallon,
  currencyCode: 'USD',
);

/// Answers whatever the test says the registry knows about a VIN.
class FakeVinDecoder implements VinDecoder {
  FakeVinDecoder({this.decoded = const DecodedVin(), this.fails = false});

  final DecodedVin decoded;
  final bool fails;
  final List<String> looked = [];

  @override
  Future<DecodedVin> decode(String vin) async {
    looked.add(vin);
    if (fails) {
      throw const AppFailure(kind: AppFailureKind.network);
    }
    return decoded;
  }
}

Future<void> pumpEditScreen(
  WidgetTester tester, {
  required RecordingVehicleRepository repository,
  UnitPreferences preferences = _metric,
  FakeVinDecoder? decoder,
  FakeVehiclePhotoRepository? photos,
  XFile? picked,
}) {
  final router = GoRouter(
    initialLocation: '/vehicles/v1/edit',
    routes: [
      GoRoute(
        path: '/vehicles',
        builder: (_, _) => const Scaffold(body: Text('list')),
      ),
      GoRoute(
        path: '/vehicles/:id/edit',
        builder: (_, state) =>
            VehicleEditScreen(vehicleId: state.pathParameters['id']),
      ),
    ],
  );

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        vehicleRepositoryProvider.overrideWithValue(repository),
        currentHouseholdProvider.overrideWith(
          (ref) async => const Household(id: 'h1', name: 'Test'),
        ),
        unitPreferencesProvider.overrideWithValue(preferences),
        vinDecoderProvider.overrideWithValue(decoder ?? FakeVinDecoder()),
        vehiclePhotoRepositoryProvider.overrideWithValue(
          photos ?? FakeVehiclePhotoRepository(),
        ),
        filePickerProvider.overrideWithValue(() async => picked),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
}

/// Labels sit outside their fields, so tests reach a field by its position:
/// nickname, make, model, year, plate, VIN, odometer, tank capacity.
const _vinField = 5;

/// The label sits outside the field, so its helper text is what identifies the
/// tank-capacity input among the screen's other numeric fields.
const _capacityHint = 'Optional — flags a fill-up bigger than the tank';

Future<void> saveWithCapacity(WidgetTester tester, String capacity) async {
  final field = find.widgetWithText(TextFormField, _capacityHint);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, capacity);

  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('the VIN lookup', () {
    testWidgets('fills in what the registry knows', (tester) async {
      final decoder = FakeVinDecoder(
        decoded: const DecodedVin(
          make: 'Volkswagen',
          model: 'Golf',
          year: 2015,
          trim: 'Highline',
        ),
      );
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([]),
        decoder: decoder,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_vinField),
        'WVWZZZ1KZAW000001',
      );
      final lookUp = find.widgetWithText(TextButton, 'Look up');
      await tester.ensureVisible(lookUp);
      await tester.pumpAndSettle();
      await tester.tap(lookUp);
      await tester.pumpAndSettle();

      expect(decoder.looked, ['WVWZZZ1KZAW000001']);
      expect(find.text('Volkswagen'), findsOneWidget);
      expect(find.text('Golf'), findsOneWidget);
      expect(find.text('2015'), findsOneWidget);
    });

    testWidgets('says so when the VIN cannot be looked up', (tester) async {
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([]),
        decoder: FakeVinDecoder(fails: true),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_vinField),
        'WVWZZZ1KZAW000001',
      );
      final lookUp = find.widgetWithText(TextButton, 'Look up');
      await tester.ensureVisible(lookUp);
      await tester.pumpAndSettle();
      await tester.tap(lookUp);
      await tester.pumpAndSettle();

      expect(find.text('That VIN could not be looked up'), findsOneWidget);
    });

    testWidgets('a registry that knows nothing says so too', (tester) async {
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([]),
        decoder: FakeVinDecoder(),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(_vinField),
        'WVWZZZ1KZAW000001',
      );
      final lookUp = find.widgetWithText(TextButton, 'Look up');
      await tester.ensureVisible(lookUp);
      await tester.pumpAndSettle();
      await tester.tap(lookUp);
      await tester.pumpAndSettle();

      expect(find.text('That VIN could not be looked up'), findsOneWidget);
    });
  });

  testWidgets('an existing capacity prefills in the household unit', (
    tester,
  ) async {
    await pumpEditScreen(
      tester,
      repository: RecordingVehicleRepository([car(tankCapacityL: 55)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('55'), findsOneWidget);
    expect(find.text('l'), findsOneWidget);
  });

  testWidgets('a capacity in gallons prefills converted, with its own unit', (
    tester,
  ) async {
    await pumpEditScreen(
      tester,
      repository: RecordingVehicleRepository([car(tankCapacityL: 55)]),
      preferences: _imperial,
    );
    await tester.pumpAndSettle();

    expect(find.text('14.5'), findsOneWidget);
    expect(find.text('gal'), findsOneWidget);
  });

  testWidgets('saving stores litres, whatever unit was typed in', (
    tester,
  ) async {
    final repository = RecordingVehicleRepository([car()]);
    await pumpEditScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await saveWithCapacity(tester, '60');

    expect(repository.updated?.tankCapacityL, closeTo(60, 0.0001));
  });

  testWidgets('a capacity typed in gallons is converted to litres', (
    tester,
  ) async {
    final repository = RecordingVehicleRepository([car()]);
    await pumpEditScreen(
      tester,
      repository: repository,
      preferences: _imperial,
    );
    await tester.pumpAndSettle();

    await saveWithCapacity(tester, '15');

    expect(repository.updated?.tankCapacityL, closeTo(56.781, 0.001));
  });

  testWidgets('leaving the capacity blank stores nothing', (tester) async {
    final repository = RecordingVehicleRepository([car(tankCapacityL: 55)]);
    await pumpEditScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await saveWithCapacity(tester, '');

    expect(repository.updated?.tankCapacityL, isNull);
  });

  testWidgets('a comma decimal separator is accepted', (tester) async {
    final repository = RecordingVehicleRepository([car()]);
    await pumpEditScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await saveWithCapacity(tester, '62,5');

    expect(repository.updated?.tankCapacityL, closeTo(62.5, 0.0001));
  });

  group('the vehicle photo', () {
    XFile pickedPhoto() => XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4, 5]),
      name: 'golf.jpg',
      path: 'golf.jpg',
      mimeType: 'image/jpeg',
    );

    testWidgets('a vehicle without one offers to add one', (tester) async {
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a photo'), findsOneWidget);
    });

    testWidgets('picking one uploads it against the vehicle', (tester) async {
      final photos = FakeVehiclePhotoRepository();
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car()]),
        photos: photos,
        picked: pickedPhoto(),
      );
      await tester.pumpAndSettle();

      final button = find.text('Add a photo');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(photos.calls, contains('upload:h1/v1:5'));
    });

    testWidgets('the stored path is saved with the vehicle', (tester) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(
        tester,
        repository: repository,
        photos: FakeVehiclePhotoRepository(),
        picked: pickedPhoto(),
      );
      await tester.pumpAndSettle();

      final button = find.text('Add a photo');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await saveWithCapacity(tester, '55');

      expect(repository.updated?.photoUrl, 'h1/v1');
    });

    testWidgets('cancelling the picker uploads nothing', (tester) async {
      final photos = FakeVehiclePhotoRepository();
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car()]),
        photos: photos,
      );
      await tester.pumpAndSettle();

      final button = find.text('Add a photo');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(photos.calls, isEmpty);
    });
  });
}
