import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every list the read cache holds a copy of is refetched by `invalidateReads`
/// (`lib/core/sync/invalidate_reads.dart`): the banner's Retry, a resume and a
/// queue replay all go through it, and `unmarkAll()` clears the stale marks
/// first. A cached family missing from the list keeps showing its copy after
/// the banner has cleared, which is how the pending-handovers card and the
/// incidents list stayed old on a phone that launched offline.
///
/// The families are read off the repositories — the first string literal each
/// `_cache.rows(` is given, up to its `/` — and each has to name the provider
/// or providers that read it. A new family fails here until it is mapped, and
/// a mapped provider fails until the list invalidates it.
void main() {
  const providersByFamily = {
    'fuel': ['rawFuelEntriesProvider'],
    'odometer': ['odometerEntriesProvider'],
    'services': ['serviceEntriesProvider'],
    'rules': ['reminderRulesProvider'],
    'service_types': ['serviceTypesProvider'],
    'costs': ['costEntriesProvider'],
    'income': ['incomeEntriesProvider'],
    'trips': ['tripEntriesProvider', 'allTripsProvider'],
    'routes': ['routesProvider'],
    'observations': ['observationsProvider'],
    'documents': ['vehicleDocumentsProvider'],
    'tyres': ['tyreSetsProvider'],
    'parts': ['vehiclePartsProvider'],
    'passes': [
      'vehicleGuestPassesProvider',
      'myGuestPassesProvider',
      'garagePassesProvider',
    ],
    'members': ['membersProvider'],
    'assignments': ['fleetAssignmentsProvider', 'myAssignmentsProvider'],
    // The fleet's list derives from the family, so the family is enough.
    'incidents': ['incidentsProvider'],
  };

  final families = <String, Set<String>>{};
  final key = RegExp(r"_cache\.rows\(\s*'([^'$/]+)");
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) {
      continue;
    }
    for (final match in key.allMatches(file.readAsStringSync())) {
      families.putIfAbsent(match.group(1)!, () => {}).add(file.path);
    }
  }
  final invalidations = File(
    'lib/core/sync/invalidate_reads.dart',
  ).readAsStringSync();

  test('the repositories are actually being read', () {
    expect(families.keys, containsAll(['fuel', 'assignments', 'incidents']));
  });

  test('every cached family names the providers that read it', () {
    final unmapped = [
      for (final MapEntry(key: family, value: files) in families.entries)
        if (!providersByFamily.containsKey(family))
          '$family (${files.join(', ')})',
    ];

    expect(
      unmapped,
      isEmpty,
      reason:
          'add the family to providersByFamily here and its provider to '
          'invalidate_reads.dart',
    );
  });

  test('every mapped provider is invalidated', () {
    final missing = [
      for (final providers in providersByFamily.values)
        for (final provider in providers)
          if (!invalidations.contains('invalidate($provider)')) provider,
    ];

    expect(missing, isEmpty, reason: 'add it to _invalidate');
  });

  test('the map does not outlive its families', () {
    final stale = providersByFamily.keys.where(
      (family) => !families.containsKey(family),
    );

    expect(stale, isEmpty, reason: 'the family is gone; drop the mapping');
  });
}
