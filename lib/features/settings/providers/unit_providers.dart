import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/unit_format.dart';
import '../../../domain/entities/household.dart';
import '../../household/providers/household_providers.dart';

/// Maps a household's stored unit strings to the display preferences. The
/// database is the source of truth; Task 11's settings screen writes these
/// columns and this provider reflects them. Falls back to metric/EUR before a
/// household exists.
UnitPreferences preferencesFor(Household? household) {
  if (household == null) {
    return const UnitPreferences(
      distance: DistanceUnit.km,
      volume: VolumeUnit.liter,
      currencyCode: 'EUR',
    );
  }
  return UnitPreferences(
    distance: household.distanceUnit == 'mi' ? DistanceUnit.mi : DistanceUnit.km,
    volume: switch (household.volumeUnit) {
      'us_gallon' => VolumeUnit.usGallon,
      'uk_gallon' => VolumeUnit.ukGallon,
      _ => VolumeUnit.liter,
    },
    currencyCode: household.currencyCode,
  );
}

/// The household's display units. Widgets combine this with the active locale
/// to build a [UnitFormat].
final unitPreferencesProvider = Provider<UnitPreferences>((ref) {
  return preferencesFor(ref.watch(currentHouseholdProvider).value);
});
