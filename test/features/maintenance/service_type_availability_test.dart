import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';

const _types = [
  ServiceType(key: 'service_oil_change', defaultIntervalKm: 15000),
  ServiceType(
    key: 'service_registration',
    isStatutory: true,
    countryCode: 'HR',
  ),
  ServiceType(
    key: 'service_technical_inspection',
    isStatutory: true,
    countryCode: 'HR',
  ),
  ServiceType(key: 'service_mot', isStatutory: true, countryCode: 'GB'),
  // A household's own statutory item, with no country of its own.
  ServiceType(key: 'service_custom_check', isStatutory: true),
];

ProviderContainer containerWith(String countryCode) {
  final container = ProviderContainer(
    overrides: [
      serviceTypesProvider.overrideWith((ref) async => _types),
      currentHouseholdProvider.overrideWith(
        (ref) async =>
            Household(id: 'h1', name: 'Test', countryCode: countryCode),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'a Croatian household is offered the Croatian statutory items',
    () async {
      final container = containerWith('HR');

      final types = await container.read(availableServiceTypesProvider.future);

      expect(types.map((t) => t.key), [
        'service_oil_change',
        'service_registration',
        'service_technical_inspection',
        'service_custom_check',
      ]);
    },
  );

  test('another country does not see them', () async {
    final container = containerWith('GB');

    final types = await container.read(availableServiceTypesProvider.future);

    expect(types.map((t) => t.key), [
      'service_oil_change',
      'service_mot',
      'service_custom_check',
    ]);
  });

  test(
    'a country with no statutory rows still gets the universal ones',
    () async {
      final container = containerWith('DE');

      final types = await container.read(availableServiceTypesProvider.future);

      expect(types.map((t) => t.key), [
        'service_oil_change',
        'service_custom_check',
      ]);
    },
  );

  test('the country match ignores case', () async {
    final container = containerWith('hr');

    final types = await container.read(availableServiceTypesProvider.future);

    expect(types.map((t) => t.key), contains('service_registration'));
  });
}
