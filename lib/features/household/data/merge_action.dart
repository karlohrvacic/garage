import '../../../domain/entities/household.dart';
import '../../vehicles/data/vehicle_photo_repository.dart';
import '../../vehicles/data/vehicle_repository.dart';
import 'household_repository.dart';

/// The two garages keep their money in different currencies.
///
/// Its own type rather than a generic failure because it is the one refusal
/// with an answer the user can act on — change one garage's currency first —
/// and because it must be caught before anything moves.
class MergeCurrencyMismatch implements Exception {
  const MergeCurrencyMismatch(this.absorbed, this.surviving);

  final String absorbed;
  final String surviving;
}

/// Empties one garage into another.
///
/// **Photos are re-homed first, and that ordering is not arbitrary.** A
/// vehicle photo is stored under its garage's prefix, and the storage policy
/// resolves that prefix through the caller's memberships. The moment the merge
/// lands, the absorbed garage is gone and its prefix stops being readable — so
/// a photo not copied by then can never be copied at all. It is also why the
/// currency check happens here rather than only in the database: a refusal
/// after the copying would leave photos moved for a merge that never happened.
///
/// The database re-checks everything regardless. This is the cheap half, not
/// the authority.
Future<MergeOutcome> mergeGarages({
  required HouseholdRepository households,
  required VehicleRepository vehicles,
  required VehiclePhotoRepository photos,
  required Household absorbed,
  required Household surviving,
}) async {
  if (absorbed.currencyCode != surviving.currencyCode) {
    throw MergeCurrencyMismatch(absorbed.currencyCode, surviving.currencyCode);
  }

  var photosLost = 0;
  for (final vehicle in await vehicles.forHousehold(absorbed.id)) {
    final path = vehicle.photoUrl;
    if (path == null || path.isEmpty) {
      continue;
    }
    final bytes = await photos.download(path);
    if (bytes == null) {
      photosLost++;
      continue;
    }
    try {
      final moved = await photos.upload(
        householdId: surviving.id,
        vehicleId: vehicle.id,
        bytes: bytes,
      );
      await vehicles.update(vehicle.copyWith(photoUrl: moved));
    } catch (_) {
      // Counted and carried on. A picture is worth less than a garage left
      // half-merged because one upload timed out.
      photosLost++;
    }
  }

  final outcome = await households.merge(
    absorbedHouseholdId: absorbed.id,
    survivingHouseholdId: surviving.id,
  );
  return MergeOutcome(
    vehiclesMoved: outcome.vehiclesMoved,
    membersMoved: outcome.membersMoved,
    keysRevoked: outcome.keysRevoked,
    photosLost: photosLost,
  );
}
