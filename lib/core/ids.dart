import 'dart:math';

/// A fresh id for an entry the app is about to create.
///
/// Generated on the device, when the sheet opens, rather than by the
/// database on insert: a write that times out cannot be cancelled, so the
/// same entry saved again must carry the same id, and land as "already
/// there" instead of as a second row. Version 4 UUID, from the secure
/// generator, in the lower-case form Postgres prints.
String newEntryId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
