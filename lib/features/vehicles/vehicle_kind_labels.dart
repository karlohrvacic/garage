import 'package:garage/l10n/app_localizations.dart';

/// What a vehicle is, in the order offered. Keys match the check constraint
/// in migration 0047.
const vehicleKindKeys = ['car', 'motorcycle', 'van'];

/// How a motorcycle's rear wheel is driven. Keys match migration 0047.
const finalDriveKeys = ['chain', 'belt', 'shaft'];

/// The translated name for a kind, or null for one this version does not
/// know — a vehicle stored by a newer build must not crash an older one.
String? vehicleKindLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'car' => l10n.vehicleKindCar,
    'motorcycle' => l10n.vehicleKindMotorcycle,
    'van' => l10n.vehicleKindVan,
    _ => null,
  };
}

String? finalDriveLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'chain' => l10n.finalDriveChain,
    'belt' => l10n.finalDriveBelt,
    'shaft' => l10n.finalDriveShaft,
    _ => null,
  };
}
