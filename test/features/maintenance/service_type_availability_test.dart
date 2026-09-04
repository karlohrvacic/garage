import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

const _types = [
  ServiceType(key: 'service_oil_change', defaultIntervalKm: 15000),
  ServiceType(key: 'service_oil_filter'),
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
  ServiceType(key: 'service_spark_plugs'),
  ServiceType(key: 'service_glow_plugs'),
  ServiceType(key: 'service_fuel_filter'),
  ServiceType(key: 'service_dpf'),
  ServiceType(key: 'service_adblue'),
  ServiceType(key: 'service_timing_belt'),
  ServiceType(key: 'service_cabin_filter'),
  ServiceType(key: 'service_chain_lube'),
  ServiceType(key: 'service_chain_sprockets'),
  ServiceType(key: 'service_fork_oil'),
  ServiceType(key: 'service_valve_clearance'),
];

ProviderContainer containerWith(
  String countryCode, {
  String fuel = 'fuel_petrol',
  String kind = 'car',
  String? finalDrive,
}) {
  final container = ProviderContainer(
    overrides: [
      serviceTypesProvider.overrideWith((ref) async => _types),
      currentHouseholdProvider.overrideWith(
        (ref) async =>
            Household(id: 'h1', name: 'Test', countryCode: countryCode),
      ),
      // The fleet rather than one vehicle, so an id that is not in it
      // resolves to null the way it does in the app instead of reaching for
      // a client.
      allVehiclesProvider.overrideWith(
        (ref) async => [
          Vehicle(
            id: 'v1',
            householdId: 'h1',
            nickname: 'Car',
            fuelTypeKey: fuel,
            kind: kind,
            finalDrive: finalDrive,
            baselineOdometerKm: 0,
            baselineDate: DateTime.utc(2026, 1, 1),
          ),
        ],
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

      final types = await container.read(
        availableServiceTypesProvider('v1').future,
      );

      expect(types.map((t) => t.key), [
        'service_oil_change',
        'service_oil_filter',
        'service_registration',
        'service_technical_inspection',
        'service_custom_check',
        'service_spark_plugs',
        'service_timing_belt',
        'service_cabin_filter',
      ]);
    },
  );

  test('another country does not see them', () async {
    final container = containerWith('GB');

    final types = await container.read(
      availableServiceTypesProvider('v1').future,
    );

    expect(types.map((t) => t.key), [
      'service_oil_change',
      'service_oil_filter',
      'service_mot',
      'service_custom_check',
      'service_spark_plugs',
      'service_timing_belt',
      'service_cabin_filter',
    ]);
  });

  test(
    'a country with no statutory rows still gets the universal ones',
    () async {
      final container = containerWith('DE');

      final types = await container.read(
        availableServiceTypesProvider('v1').future,
      );

      expect(types.map((t) => t.key), [
        'service_oil_change',
        'service_oil_filter',
        'service_custom_check',
        'service_spark_plugs',
        'service_timing_belt',
        'service_cabin_filter',
      ]);
    },
  );

  test('the country match ignores case', () async {
    final container = containerWith('hr');

    final types = await container.read(
      availableServiceTypesProvider('v1').future,
    );

    expect(types.map((t) => t.key), contains('service_registration'));
  });

  test('a diesel is offered glow plugs, not spark plugs', () async {
    final container = containerWith('HR', fuel: 'fuel_diesel');

    final keys = (await container.read(
      availableServiceTypesProvider('v1').future,
    )).map((t) => t.key);

    expect(keys, contains('service_glow_plugs'));
    expect(keys, contains('service_fuel_filter'));
    expect(keys, contains('service_dpf'));
    expect(keys, contains('service_adblue'));
    expect(keys, isNot(contains('service_spark_plugs')));
  });

  test('an electric car is offered nothing that burns fuel', () async {
    final container = containerWith('HR', fuel: 'fuel_electric');

    final keys = (await container.read(
      availableServiceTypesProvider('v1').future,
    )).map((t) => t.key);

    expect(keys, isNot(contains('service_oil_change')));
    expect(keys, isNot(contains('service_oil_filter')));
    expect(keys, isNot(contains('service_timing_belt')));
    expect(keys, isNot(contains('service_spark_plugs')));
    expect(keys, isNot(contains('service_fuel_filter')));
    expect(keys, contains('service_registration'));
  });

  test('a hybrid keeps everything a petrol has', () async {
    final petrol = (await containerWith('HR').read(
      availableServiceTypesProvider('v1').future,
    )).map((t) => t.key).toList();
    final hybrid = (await containerWith('HR', fuel: 'fuel_hybrid').read(
      availableServiceTypesProvider('v1').future,
    )).map((t) => t.key).toList();

    expect(hybrid, petrol);
  });

  test('a fuel this build does not know hides nothing', () async {
    // A newer build may record a fuel key this one has no case for. Guessing
    // it is petrol would hide the diesel types from a car that may need them.
    final container = containerWith('HR', fuel: 'fuel_hvo');

    final keys = (await container.read(
      availableServiceTypesProvider('v1').future,
    )).map((t) => t.key);

    expect(keys, contains('service_glow_plugs'));
    expect(keys, contains('service_spark_plugs'));
  });

  test('a household with no such vehicle is offered the full list', () async {
    // The sheet can open for a vehicle id the provider does not resolve; a
    // shorter list would hide things for no reason anyone could see.
    final container = containerWith('HR');

    final keys = (await container.read(
      availableServiceTypesProvider('missing').future,
    )).map((t) => t.key);

    expect(keys, contains('service_glow_plugs'));
    expect(keys, contains('service_spark_plugs'));
  });

  group('the vehicle kind', () {
    test('a car is not offered chain, fork or valve work', () async {
      final keys = (await containerWith(
        'HR',
      ).read(availableServiceTypesProvider('v1').future)).map((t) => t.key);

      expect(keys, contains('service_cabin_filter'));
      expect(keys, isNot(contains('service_chain_lube')));
      expect(keys, isNot(contains('service_chain_sprockets')));
      expect(keys, isNot(contains('service_fork_oil')));
      expect(keys, isNot(contains('service_valve_clearance')));
    });

    test('a motorcycle is offered them, and not a cabin filter', () async {
      final keys = (await containerWith(
        'HR',
        kind: 'motorcycle',
      ).read(availableServiceTypesProvider('v1').future)).map((t) => t.key);

      expect(keys, contains('service_chain_lube'));
      expect(keys, contains('service_chain_sprockets'));
      expect(keys, contains('service_fork_oil'));
      expect(keys, contains('service_valve_clearance'));
      expect(keys, isNot(contains('service_cabin_filter')));
      expect(keys, contains('service_registration'));
    });

    test('a shaft-driven motorcycle has no chain to lubricate', () async {
      final keys = (await containerWith(
        'HR',
        kind: 'motorcycle',
        finalDrive: 'shaft',
      ).read(availableServiceTypesProvider('v1').future)).map((t) => t.key);

      expect(keys, isNot(contains('service_chain_lube')));
      expect(keys, isNot(contains('service_chain_sprockets')));
      expect(keys, contains('service_fork_oil'));
    });

    test('a kind this build does not know hides nothing', () async {
      final keys = (await containerWith(
        'HR',
        kind: 'tractor',
      ).read(availableServiceTypesProvider('v1').future)).map((t) => t.key);

      expect(keys, contains('service_chain_lube'));
      expect(keys, contains('service_cabin_filter'));
    });
  });
}
