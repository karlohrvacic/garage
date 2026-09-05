import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/data/merge_action.dart';
import 'package:garage/features/vehicles/data/vehicle_photo_repository.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

class FakeMergeHouseholds implements HouseholdRepository {
  final List<String> calls = [];
  Object? failWith;

  @override
  Future<MergeOutcome> merge({
    required String absorbedHouseholdId,
    required String survivingHouseholdId,
  }) async {
    calls.add('merge:$absorbedHouseholdId->$survivingHouseholdId');
    if (failWith != null) {
      throw failWith!;
    }
    return const MergeOutcome(
      vehiclesMoved: 2,
      membersMoved: 1,
      keysRevoked: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class RecordingPhotos implements VehiclePhotoRepository {
  RecordingPhotos({this.missing = const {}, this.uploadFails = const {}});

  final Set<String> missing;
  final Set<String> uploadFails;
  final List<String> uploaded = [];

  @override
  Future<Uint8List?> download(String path) async =>
      missing.contains(path) ? null : Uint8List.fromList([1, 2, 3]);

  @override
  Future<String> upload({
    required String householdId,
    required String vehicleId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (uploadFails.contains(vehicleId)) {
      throw Exception('storage refused');
    }
    uploaded.add('$householdId/$vehicleId');
    return '$householdId/$vehicleId.jpg';
  }

  @override
  Future<Uri?> viewUrl(String? path) async => null;

  @override
  Future<void> delete(String path) async {}
}

Vehicle car(String id, {String? photo}) =>
    testVehicle(id, householdId: 'old').copyWith(photoUrl: photo);

void main() {
  test('the merge happens, and reports what moved', () async {
    final households = FakeMergeHouseholds();

    final outcome = await mergeGarages(
      households: households,
      vehicles: FakeVehicleRepository(vehicles: [car('v1')]),
      photos: RecordingPhotos(),
      absorbed: const Household(id: 'old', name: 'Theirs'),
      surviving: const Household(id: 'new', name: 'Ours'),
    );

    expect(households.calls, ['merge:old->new']);
    expect(outcome.vehiclesMoved, 2);
    expect(outcome.membersMoved, 1);
    expect(outcome.keysRevoked, 1);
    expect(outcome.photosLost, 0);
  });

  test('a photo is carried into the surviving garage first', () async {
    // The file sits under the old garage's storage prefix and cannot follow a
    // car on its own. It has to be copied while the caller is still a member
    // of both, which means before the merge, not after.
    final photos = RecordingPhotos();
    final vehicles = FakeVehicleRepository(
      vehicles: [car('v1', photo: 'old/v1.jpg')],
    );

    await mergeGarages(
      households: FakeMergeHouseholds(),
      vehicles: vehicles,
      photos: photos,
      absorbed: const Household(id: 'old', name: 'Theirs'),
      surviving: const Household(id: 'new', name: 'Ours'),
    );

    expect(photos.uploaded, ['new/v1']);
    expect(vehicles.updated.single.photoUrl, 'new/v1.jpg');
  });

  test('a car with no photo is left alone', () async {
    final photos = RecordingPhotos();
    final vehicles = FakeVehicleRepository(vehicles: [car('v1')]);

    await mergeGarages(
      households: FakeMergeHouseholds(),
      vehicles: vehicles,
      photos: photos,
      absorbed: const Household(id: 'old', name: 'Theirs'),
      surviving: const Household(id: 'new', name: 'Ours'),
    );

    expect(photos.uploaded, isEmpty);
    expect(vehicles.updated, isEmpty);
  });

  test('a photo that has gone missing is counted, not fatal', () async {
    // Losing a picture is not a reason to abandon a merge halfway through.
    final households = FakeMergeHouseholds();

    final outcome = await mergeGarages(
      households: households,
      vehicles: FakeVehicleRepository(
        vehicles: [car('v1', photo: 'old/v1.jpg')],
      ),
      photos: RecordingPhotos(missing: {'old/v1.jpg'}),
      absorbed: const Household(id: 'old', name: 'Theirs'),
      surviving: const Household(id: 'new', name: 'Ours'),
    );

    expect(outcome.photosLost, 1);
    expect(households.calls, ['merge:old->new'], reason: 'it still merged');
  });

  test('a photo the storage refuses is counted too', () async {
    final outcome = await mergeGarages(
      households: FakeMergeHouseholds(),
      vehicles: FakeVehicleRepository(
        vehicles: [
          car('v1', photo: 'old/v1.jpg'),
          car('v2', photo: 'old/v2.jpg'),
        ],
      ),
      photos: RecordingPhotos(uploadFails: {'v1'}),
      absorbed: const Household(id: 'old', name: 'Theirs'),
      surviving: const Household(id: 'new', name: 'Ours'),
    );

    expect(outcome.photosLost, 1, reason: 'v2 still made it');
  });

  test('a currency mismatch is refused before a single photo moves', () async {
    // Photos have to be copied *before* the merge — afterwards the old
    // garage's storage prefix is no longer readable, because the caller has
    // stopped being a member of it. So the one precondition the client can
    // check cheaply is checked first, or a refused merge leaves photos moved
    // for a merge that never happened. The database re-checks it regardless.
    final photos = RecordingPhotos();
    final households = FakeMergeHouseholds();

    await expectLater(
      mergeGarages(
        households: households,
        vehicles: FakeVehicleRepository(
          vehicles: [car('v1', photo: 'old/v1.jpg')],
        ),
        photos: photos,
        absorbed: const Household(
          id: 'old',
          name: 'Theirs',
          currencyCode: 'USD',
        ),
        surviving: const Household(id: 'new', name: 'Ours'),
      ),
      throwsA(isA<MergeCurrencyMismatch>()),
    );
    expect(photos.uploaded, isEmpty);
    expect(households.calls, isEmpty);
  });

  test('a merge the database refuses still surfaces the failure', () async {
    final households = FakeMergeHouseholds()..failWith = Exception('refused');

    await expectLater(
      mergeGarages(
        households: households,
        vehicles: FakeVehicleRepository(vehicles: [car('v1')]),
        photos: RecordingPhotos(),
        absorbed: const Household(id: 'old', name: 'Theirs'),
        surviving: const Household(id: 'new', name: 'Ours'),
      ),
      throwsA(isA<Exception>()),
    );
  });
}
