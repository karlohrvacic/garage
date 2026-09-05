/// What a document's expiry date means today.
///
/// The app tracks money and work and knew nothing about paper, which is the
/// part that carries a fine. A registration that lapsed is not a degraded
/// service interval — it is a car that may not legally be on the road — so
/// the states here are deliberately not the maintenance ones: nothing about a
/// certificate is "due in a while, at your convenience".
library;

import '../entities/vehicle_document.dart';

/// How far ahead of the date a document starts reading as expiring.
///
/// A month rather than the fortnight maintenance uses. Renewing paperwork
/// means booking a slot at a testing station or getting a quote from an
/// insurer, and both take longer to arrange than an afternoon in a garage.
const int documentNoticeDays = 30;

enum DocumentExpiryState {
  /// No date recorded. Distinct from valid on purpose: an app that showed a
  /// document with no expiry as "valid" would be asserting something nobody
  /// told it.
  undated,
  valid,
  expiring,
  expired,
}

/// Calendar days from [today] until [expiresOn]: zero on the day itself and
/// negative once it has passed.
///
/// Both dates are normalised to a UTC midnight before subtracting, so a
/// daylight-saving boundary between them cannot turn ten days into nine and a
/// half.
int? daysUntilExpiry({required DateTime? expiresOn, required DateTime today}) {
  if (expiresOn == null) {
    return null;
  }
  final from = DateTime.utc(today.year, today.month, today.day);
  final to = DateTime.utc(expiresOn.year, expiresOn.month, expiresOn.day);
  return to.difference(from).inDays;
}

/// Where a document stands today.
///
/// The last valid day is still valid. A certificate valid *until* the 4th
/// covers the 4th, and calling it expired that morning would send somebody to
/// a testing station a day early every single year.
DocumentExpiryState documentExpiryState({
  required DateTime? expiresOn,
  required DateTime today,
}) {
  final days = daysUntilExpiry(expiresOn: expiresOn, today: today);
  if (days == null) {
    return DocumentExpiryState.undated;
  }
  if (days < 0) {
    return DocumentExpiryState.expired;
  }
  return days <= documentNoticeDays
      ? DocumentExpiryState.expiring
      : DocumentExpiryState.valid;
}

/// The documents ordered by how soon they need attention, undated last.
///
/// Returns a new list: sorting the caller's own list in place would reorder
/// whatever a provider is holding, and a screen that rebuilt mid-scroll would
/// shuffle under the reader's finger.
List<VehicleDocument> documentsByUrgency(Iterable<VehicleDocument> documents) {
  final sorted = documents.toList();
  sorted.sort((a, b) {
    final left = a.expiresOn;
    final right = b.expiresOn;
    if (left == null && right == null) {
      return a.type.key.compareTo(b.type.key);
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  });
  return sorted;
}
