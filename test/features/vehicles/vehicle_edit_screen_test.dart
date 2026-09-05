import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/features/vehicles/data/vin_decoder.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicle_edit_screen.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:cross_file/cross_file.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';

import 'vehicle_photo_repository_test.dart' show FakeVehiclePhotoRepository;

class RecordingVehicleRepository implements VehicleRepository {
  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async =>
      const [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> cancelTransfer(String vehicleId) async {}

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async => null;

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

Vehicle car({double? tankCapacityL, String? photoUrl, double? purchasePrice}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    tankCapacityL: tankCapacityL,
    photoUrl: photoUrl,
    purchasePrice: purchasePrice,
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
  bool creating = false,
}) {
  final router = GoRouter(
    initialLocation: creating ? '/vehicles/new' : '/vehicles/v1/edit',
    routes: [
      GoRoute(
        path: '/vehicles',
        builder: (_, _) => const Scaffold(body: Text('list')),
      ),
      GoRoute(
        path: '/vehicles/new',
        builder: (_, _) => const VehicleEditScreen(vehicleId: null),
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

/// The label sits outside the field, so its helper text is what identifies the
/// tank-capacity input among the screen's other numeric fields.
const _capacityHint = 'Flags a fill-up bigger than the tank';

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

/// The purchase-price box, then Save. The form is long and lazily built, so
/// both have to be scrolled to before they can be touched.
Future<void> saveWithPrice(WidgetTester tester, String price) async {
  final field = find.byKey(const Key('vehicle-purchase-price'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, price);
  await tester.pumpAndSettle();

  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('the VIN lookup', () {
    testWidgets('says what it does before it is used', (tester) async {
      // "Look up" beside an empty field gave no hint what it needs or gives.
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(
        find.text('Fills in make, model and year from the number'),
        findsOneWidget,
      );
    });

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
        find.byKey(const Key('vehicle-vin')),
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
        find.byKey(const Key('vehicle-vin')),
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
        find.byKey(const Key('vehicle-vin')),
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

  testWidgets('a VIN of the wrong length is refused before saving', (
    tester,
  ) async {
    // The database rejects a VIN outside 11–17 characters, and that rejection
    // reached the screen as "something went wrong" — a red field with the rule
    // under it is what a typo deserves.
    final repository = RecordingVehicleRepository([car()]);
    await pumpEditScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('vehicle-vin')), 'WVW123');
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.updated, isNull);
    expect(find.text('A VIN is 11 to 17 characters long'), findsOneWidget);
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

    /// Bytes too short to decode skip the crop screen entirely — see
    /// `isCroppableImage`. These tests need something the codec can actually
    /// lay out on a canvas.
    XFile realPickedPhoto() {
      final image = img.Image(width: 40, height: 40);
      img.fill(image, color: img.ColorRgb8(80, 120, 200));
      return XFile.fromData(
        Uint8List.fromList(img.encodeJpg(image, quality: 90)),
        name: 'golf.jpg',
        path: 'golf.jpg',
        mimeType: 'image/jpeg',
      );
    }

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

    testWidgets('a real photo opens a cropping editor first', (tester) async {
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car()]),
        photos: FakeVehiclePhotoRepository(),
        picked: realPickedPhoto(),
      );
      await tester.pumpAndSettle();

      final button = find.text('Add a photo');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Frame the photo'), findsOneWidget);
    });

    testWidgets('confirming the crop uploads the cropped photo', (
      tester,
    ) async {
      final photos = FakeVehiclePhotoRepository();
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car()]),
        photos: photos,
        picked: realPickedPhoto(),
      );
      await tester.pumpAndSettle();

      final button = find.text('Add a photo');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      // The editor parses the image in a real isolate via `compute`, which
      // needs real wall-clock time to reply — not just more pumped frames.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      // Cropping itself also runs through `compute`.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(photos.calls, hasLength(1));
      expect(photos.calls.single, startsWith('upload:h1/v1:'));
    });

    testWidgets('backing out of cropping uploads nothing', (tester) async {
      final photos = FakeVehiclePhotoRepository();
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car()]),
        photos: photos,
        picked: realPickedPhoto(),
      );
      await tester.pumpAndSettle();

      final button = find.text('Add a photo');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(photos.calls, isEmpty);
      expect(find.text('Add a photo'), findsOneWidget);
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

    testWidgets('a vehicle with one offers to remove it', (tester) async {
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car(photoUrl: 'h1/v1')]),
        photos: FakeVehiclePhotoRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('removing it asks first', (tester) async {
      final photos = FakeVehiclePhotoRepository();
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car(photoUrl: 'h1/v1')]),
        photos: photos,
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byIcon(Icons.delete_outline);
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsOneWidget);
      expect(photos.calls.where((c) => c.startsWith('delete')), isEmpty);
    });

    testWidgets('a confirmed removal deletes it from storage', (tester) async {
      final photos = FakeVehiclePhotoRepository();
      await pumpEditScreen(
        tester,
        repository: RecordingVehicleRepository([car(photoUrl: 'h1/v1')]),
        photos: photos,
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byIcon(Icons.delete_outline);
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(photos.calls, contains('delete:h1/v1'));
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Add a photo'), findsOneWidget);
    });

    testWidgets('a removal is saved with the vehicle', (tester) async {
      final repository = RecordingVehicleRepository([car(photoUrl: 'h1/v1')]);
      await pumpEditScreen(
        tester,
        repository: repository,
        photos: FakeVehiclePhotoRepository(),
      );
      await tester.pumpAndSettle();

      final deleteButton = find.byIcon(Icons.delete_outline);
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      await saveWithCapacity(tester, '55');

      expect(repository.updated?.photoUrl, isNull);
    });
  });

  // Every other optional field on this form clears by emptying it — make,
  // model, plate, VIN, tank capacity all go through `_emptyToNull` and are
  // written as null. The purchase price alone was saved as
  // `_purchasePriceAmount() ?? existing.purchasePrice`, so emptying the box
  // put the old figure straight back and the household had no way to take a
  // wrong price out again.
  testWidgets('clearing the purchase price removes it', (tester) async {
    final repository = RecordingVehicleRepository([car(purchasePrice: 12500)]);
    await pumpEditScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await saveWithPrice(tester, '');

    expect(repository.updated, isNotNull);
    expect(repository.updated!.purchasePrice, isNull);
  });

  testWidgets('and a price typed in is still stored', (tester) async {
    final repository = RecordingVehicleRepository([car()]);
    await pumpEditScreen(tester, repository: repository);
    await tester.pumpAndSettle();

    await saveWithPrice(tester, '9750');

    expect(repository.updated!.purchasePrice, 9750);
  });

  group('timing drive and gearbox', () {
    // Both start as "Not set" and save as null: the only wrong answer is a
    // guessed one, because the timing-belt default it drives can cost an
    // engine.
    testWidgets('an untouched form saves neither', (tester) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.timingDrive, isNull);
      expect(repository.updated?.transmission, isNull);
    });

    testWidgets('choosing both saves their keys', (tester) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      final timing = find.byKey(const Key('vehicle-timing-drive'));
      await tester.ensureVisible(timing);
      await tester.pumpAndSettle();
      await tester.tap(timing);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belt-in-oil').last);
      await tester.pumpAndSettle();

      final gearbox = find.byKey(const Key('vehicle-transmission'));
      await tester.ensureVisible(gearbox);
      await tester.pumpAndSettle();
      await tester.tap(gearbox);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dual-clutch, wet').last);
      await tester.pumpAndSettle();

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.timingDrive, 'wet_belt');
      expect(repository.updated?.transmission, 'dct_wet');
    });

    testWidgets('editing a car shows what was saved', (tester) async {
      final repository = RecordingVehicleRepository([
        car().copyWith(timingDrive: 'chain', transmission: 'cvt'),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      final timing = find.byKey(const Key('vehicle-timing-drive'));
      await tester.ensureVisible(timing);
      await tester.pumpAndSettle();

      expect(find.text('Chain'), findsOneWidget);
      expect(find.text('CVT'), findsOneWidget);
    });

    testWidgets('the belt-in-oil choice explains itself', (tester) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      final timing = find.byKey(const Key('vehicle-timing-drive'));
      await tester.ensureVisible(timing);
      await tester.pumpAndSettle();

      expect(find.textContaining('PureTech'), findsOneWidget);
    });
  });

  group('vehicle kind', () {
    testWidgets('a new vehicle is a car unless told otherwise', (tester) async {
      final repository = RecordingVehicleRepository([]);
      await pumpEditScreen(tester, repository: repository, creating: true);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Vespa');
      await tester.pumpAndSettle();
      final optional = find.text('Optional details');
      await tester.ensureVisible(optional);
      await tester.pumpAndSettle();
      await tester.tap(optional);
      await tester.pumpAndSettle();
      await saveWithCapacity(tester, '8');

      expect(repository.updated?.nickname, 'Vespa');
      expect(repository.updated?.kind, 'car');
      expect(repository.updated?.finalDrive, isNull);
      expect(find.byKey(const Key('vehicle-final-drive')), findsNothing);
    });

    testWidgets('a motorcycle can say how its rear wheel is driven', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motorcycle').last);
      await tester.pumpAndSettle();

      final drive = find.byKey(const Key('vehicle-final-drive'));
      await tester.ensureVisible(drive);
      await tester.pumpAndSettle();
      await tester.tap(drive);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shaft').last);
      await tester.pumpAndSettle();

      await saveWithCapacity(tester, '20');

      expect(repository.updated?.kind, 'motorcycle');
      expect(repository.updated?.finalDrive, 'shaft');
    });

    testWidgets('a car saves no final drive even if one was picked', (
      tester,
    ) async {
      // Switching back to a car after choosing a chain would otherwise keep
      // a rear-wheel drive on a vehicle the form no longer asks about.
      final repository = RecordingVehicleRepository([
        car().copyWith(kind: 'motorcycle', finalDrive: 'chain'),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      // The motorcycle arrived prefilled: kind shown, drive shown and set.
      expect(find.text('Motorcycle'), findsOneWidget);
      expect(find.byKey(const Key('vehicle-final-drive')), findsOneWidget);
      expect(find.text('Chain'), findsOneWidget);

      await tester.tap(find.byKey(const Key('vehicle-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car').last);
      await tester.pumpAndSettle();

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.kind, 'car');
      expect(repository.updated?.finalDrive, isNull);
    });
  });

  group('the form is short until you open the rest', () {
    // Fuel, second fuel, belt-or-chain and gearbox came before the car's
    // name and model, two of them defaulting to "Not set", so the first
    // form read as a mechanic's tool. They are folded away on a new car and
    // open when editing one, where they already have answers.
    testWidgets('a new vehicle folds the engine and optional sections', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([]);
      await pumpEditScreen(tester, repository: repository, creating: true);
      await tester.pumpAndSettle();

      expect(find.text('Engine and fuel'), findsOneWidget);
      expect(find.text('Optional details'), findsOneWidget);
      expect(find.byKey(const Key('vehicle-timing-drive')), findsNothing);
      expect(find.text('Make'), findsOneWidget);
    });

    testWidgets('editing a vehicle opens them', (tester) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vehicle-timing-drive')), findsOneWidget);
    });

    testWidgets('a rejected field inside a folded section unfolds it', (
      tester,
    ) async {
      // The VIN is validated while folded, but a red line nobody can see is
      // a Save button that does nothing.
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('vehicle-vin')), 'WVW123');
      await tester.pumpAndSettle();
      final heading = find.text('Engine and fuel');
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      await tester.tap(heading);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vehicle-vin')), findsNothing);

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.updated, isNull);
      final error = find.text('A VIN is 11 to 17 characters long');
      expect(error, findsOneWidget);
      // Unfolded is not enough: the section opened while the viewport stayed
      // on Make and Model, two screens above the red line.
      expect(tester.getRect(error).bottom, lessThan(600));
    });

    testWidgets('a missing name brings the name up, and unfolds nothing', (
      tester,
    ) async {
      // Saving an empty form scrolled to the VIN and opened the engine
      // section, leaving the one real complaint — the empty name — off the
      // screen behind a section nobody had asked to open.
      final repository = RecordingVehicleRepository([]);
      await pumpEditScreen(tester, repository: repository, creating: true);
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repository.updated, isNull);
      final error = find.text('Enter a name');
      expect(error, findsOneWidget);
      expect(tester.getRect(error).bottom, lessThan(600));
      // The engine section holds the VIN and has nothing to do with a name.
      expect(find.byKey(const Key('vehicle-vin')), findsNothing);
    });

    testWidgets('a corrected field stops being red as it is typed in', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      final vin = find.byKey(const Key('vehicle-vin'));
      await tester.enterText(vin, 'WVW123');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('A VIN is 11 to 17 characters long'), findsOneWidget);

      await tester.enterText(vin, 'WVWZZZ1KZAW123456');
      await tester.pumpAndSettle();

      expect(find.text('A VIN is 11 to 17 characters long'), findsNothing);
    });
  });

  group('a key this build does not know', () {
    // A newer build, or a backup restored from one, can store a fuel type or
    // a vehicle kind this version's list lacks. A dropdown whose value is
    // absent from its items asserts in debug and renders blank in release,
    // and saving the blank field would quietly rewrite the stored key.
    testWidgets('an unknown fuel type stays selectable and saves unchanged', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([
        car().copyWith(fuelTypeKey: 'fuel_hydrogen'),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      // Shown as the raw key, which is the honest fallback: this build has no
      // name for it, and inventing one would be worse than showing the key.
      expect(find.text('fuel_hydrogen'), findsOneWidget);

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.fuelTypeKey, 'fuel_hydrogen');
    });

    testWidgets('an unknown kind survives an edit that never touched it', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([
        car().copyWith(kind: 'quadricycle'),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('quadricycle'), findsOneWidget);

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.kind, 'quadricycle');
    });

    testWidgets('an unknown gearbox and timing drive survive too', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([
        car().copyWith(timingDrive: 'gears', transmission: 'imt'),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      final timing = find.byKey(const Key('vehicle-timing-drive'));
      await tester.ensureVisible(timing);
      await tester.pumpAndSettle();
      expect(find.text('gears'), findsOneWidget);
      expect(find.text('imt'), findsOneWidget);

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.timingDrive, 'gears');
      expect(repository.updated?.transmission, 'imt');
    });
  });

  group('what the car is worth now', () {
    /// The valuation box, then Save. Same shape as [saveWithPrice].
    Future<void> saveWithValue(WidgetTester tester, String value) async {
      final field = find.byKey(const Key('vehicle-current-value'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, value);
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
    }

    testWidgets('is saved, and stamped with the day it was said', (
      tester,
    ) async {
      final repository = RecordingVehicleRepository([car()]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await saveWithValue(tester, '9500');

      final now = DateTime.now();
      expect(repository.updated?.currentValue, 9500);
      expect(
        repository.updated?.valuedOn,
        DateTime.utc(now.year, now.month, now.day),
      );
    });

    testWidgets('keeps its original date when the figure is not touched', (
      tester,
    ) async {
      // Re-stamping an untouched number every time the form is saved would
      // make a three-year-old valuation read as today's.
      final valued = DateTime.utc(2025, 2, 1);
      final repository = RecordingVehicleRepository([
        car().copyWith(currentValue: 9500, valuedOn: valued),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await saveWithCapacity(tester, '55');

      expect(repository.updated?.currentValue, 9500);
      expect(repository.updated?.valuedOn, valued);
    });

    testWidgets('clearing it removes the date with it', (tester) async {
      final repository = RecordingVehicleRepository([
        car().copyWith(currentValue: 9500, valuedOn: DateTime.utc(2025, 2, 1)),
      ]);
      await pumpEditScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await saveWithValue(tester, '');

      expect(repository.updated?.currentValue, isNull);
      expect(repository.updated?.valuedOn, isNull);
    });
  });
}
