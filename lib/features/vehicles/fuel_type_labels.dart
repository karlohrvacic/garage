import 'package:garage/l10n/app_localizations.dart';

/// The fuel types a vehicle can be set to, in the order they are offered.
///
/// Shared rather than private to the edit screen: the Fuelio import creates
/// vehicles too, and a second list would drift from this one the first time a
/// type was added.
const fuelTypeKeys = [
  'fuel_petrol',
  'fuel_diesel',
  'fuel_lpg',
  'fuel_electric',
  'fuel_hybrid',
];

/// The translated name for a fuel key, or null for one this version does not
/// know — a vehicle stored by a newer build must not crash an older one.
String? fuelTypeLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'fuel_petrol' => l10n.fuelPetrol,
    'fuel_diesel' => l10n.fuelDiesel,
    'fuel_lpg' => l10n.fuelLpg,
    'fuel_electric' => l10n.fuelElectric,
    'fuel_hybrid' => l10n.fuelHybrid,
    _ => null,
  };
}
