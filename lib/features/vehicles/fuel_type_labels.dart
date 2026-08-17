import 'package:garage/l10n/app_localizations.dart';

/// The fuel types a vehicle can be set to, in the order they are offered.
///
/// Shared rather than private to the edit screen: the Fuelio import creates
/// vehicles too, and a second list would drift from this one the first time a
/// type was added.
const fuelTypeKeys = [
  'fuel_petrol',
  // The grades sold beside ordinary 95 at Croatian pumps. Kept as separate
  // keys rather than a note on the fill-up because a car that only ever takes
  // one of them should see its own economy, not petrol-in-general.
  'fuel_petrol_midgrade',
  'fuel_petrol_premium',
  'fuel_diesel',
  'fuel_lpg',
  'fuel_cng',
  'fuel_ethanol',
  'fuel_electric',
  'fuel_hybrid',
];

/// The translated name for a fuel key, or null for one this version does not
/// know — a vehicle stored by a newer build must not crash an older one.
String? fuelTypeLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'fuel_petrol' => l10n.fuelPetrol,
    'fuel_petrol_midgrade' => l10n.fuelPetrolMidgrade,
    'fuel_petrol_premium' => l10n.fuelPetrolPremium,
    'fuel_cng' => l10n.fuelCng,
    'fuel_ethanol' => l10n.fuelEthanol,
    'fuel_diesel' => l10n.fuelDiesel,
    'fuel_lpg' => l10n.fuelLpg,
    'fuel_electric' => l10n.fuelElectric,
    'fuel_hybrid' => l10n.fuelHybrid,
    _ => null,
  };
}
