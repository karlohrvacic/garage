import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/vehicles/data/vehicle_photo_repository.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

class FakeVehiclePhotoRepository implements VehiclePhotoRepository {
  FakeVehiclePhotoRepository({this.stored = const {}});

  Map<String, Uint8List> stored;
  final List<String> calls = [];

  @override
  Future<String> upload({
    required String householdId,
    required String vehicleId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final path = VehiclePhotos.pathFor(
      householdId: householdId,
      vehicleId: vehicleId,
    );
    calls.add('upload:$path:${bytes.length}');
    stored = {...stored, path: bytes};
    return path;
  }

  @override
  Future<Uri?> viewUrl(String? path) async {
    if (path == null) {
      return null;
    }
    calls.add('viewUrl:$path');
    return Uri.parse('https://example.test/$path');
  }

  @override
  Future<void> delete(String path) async => calls.add('delete:$path');
}

Vehicle vehicle({String? photoUrl}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    photoUrl: photoUrl,
  );
}

void main() {
  group('where a photo lives', () {
    test('is keyed household first, which is what the policy checks', () {
      expect(
        VehiclePhotos.pathFor(householdId: 'h1', vehicleId: 'v1'),
        'h1/v1',
      );
    });

    test('is the same path every time, so a new photo replaces the old', () {
      expect(
        VehiclePhotos.pathFor(householdId: 'h1', vehicleId: 'v1'),
        VehiclePhotos.pathFor(householdId: 'h1', vehicleId: 'v1'),
      );
    });
  });

  group('the photo of a vehicle', () {
    ProviderContainer containerWith(
      Vehicle subject,
      FakeVehiclePhotoRepository photos,
    ) {
      final container = ProviderContainer(
        overrides: [
          vehicleProvider('v1').overrideWith((ref) async => subject),
          vehiclePhotoRepositoryProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a vehicle without one resolves to no link', () async {
      final photos = FakeVehiclePhotoRepository();
      final container = containerWith(vehicle(), photos);

      expect(
        await container.read(vehiclePhotoUrlProvider('v1').future),
        isNull,
      );
      expect(photos.calls, isEmpty);
    });

    test('a vehicle with one resolves to a signed link', () async {
      final photos = FakeVehiclePhotoRepository();
      final container = containerWith(vehicle(photoUrl: 'h1/v1'), photos);

      final url = await container.read(vehiclePhotoUrlProvider('v1').future);

      expect(url, Uri.parse('https://example.test/h1/v1'));
      expect(photos.calls, ['viewUrl:h1/v1']);
    });

    test('a vehicle that does not exist resolves to no link', () async {
      final photos = FakeVehiclePhotoRepository();
      final container = ProviderContainer(
        overrides: [
          vehicleProvider('v1').overrideWith((ref) async => null),
          vehiclePhotoRepositoryProvider.overrideWithValue(photos),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(vehiclePhotoUrlProvider('v1').future),
        isNull,
      );
    });
  });
}
