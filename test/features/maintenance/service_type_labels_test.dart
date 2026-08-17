import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/maintenance/service_type_labels.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:garage/l10n/app_localizations_hr.dart';

/// Every preset key the migrations seed.
///
/// Read from the SQL rather than listed here, so a preset added to the
/// database without a label cannot pass: an unlabelled key falls back to
/// rendering the raw `service_brake_discs_front` at the user, which is the
/// quiet failure this guards.
Set<String> seededPresetKeys() {
  final keys = <String>{};
  for (final file in Directory('supabase/migrations').listSync()) {
    if (file is! File || !file.path.endsWith('.sql')) {
      continue;
    }
    final sql = file.readAsStringSync();
    for (final match in RegExp(r"\(null,\s*'(service_\w+)'").allMatches(sql)) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}

void main() {
  test('every seeded preset has an English label', () {
    final l10n = AppLocalizationsEn();

    for (final key in seededPresetKeys()) {
      expect(
        serviceTypeLabel(l10n, key),
        isNot(key),
        reason: '$key falls through to its raw key',
      );
    }
  });

  test('and a Croatian one', () {
    final l10n = AppLocalizationsHr();

    for (final key in seededPresetKeys()) {
      expect(
        serviceTypeLabel(l10n, key),
        isNot(key),
        reason: '$key is unlabelled in Croatian',
      );
    }
  });

  test('brakes cover discs and drums, not only pads', () {
    // The list shipped with pads front and rear and no discs at all — the
    // wrong half of the job, since discs are replaced with pads. Cars with
    // rear drums, which is most small European hatchbacks, could not record
    // their rear brakes at all.
    final seeded = seededPresetKeys();

    expect(seeded, contains('service_brake_discs_front'));
    expect(seeded, contains('service_brake_discs_rear'));
    expect(seeded, contains('service_brake_drums_rear'));
  });

  test('a diesel has somewhere to log what only a diesel has', () {
    // Spark plugs were here and glow plugs were not, on an app whose home
    // market runs largely on diesel.
    final seeded = seededPresetKeys();

    expect(seeded, contains('service_glow_plugs'));
    expect(seeded, contains('service_dpf'));
  });

  test('a key nobody knows still renders as something', () {
    // Households can add their own types; this is the documented fallback.
    expect(
      serviceTypeLabel(AppLocalizationsEn(), 'service_household_invention'),
      'service_household_invention',
    );
  });
}
