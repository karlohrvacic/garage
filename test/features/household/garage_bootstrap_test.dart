import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';
import 'package:garage/features/household/data/supabase_garage_bootstrap_repository.dart';

Map<String, dynamic> householdRow({String id = 'h1', String name = 'Hrvačić'}) {
  return {
    'id': id,
    'name': name,
    'currency_code': 'EUR',
    'distance_unit': 'km',
    'volume_unit': 'liter',
    'bundling_window_days': 21,
    'bundling_window_km': 500,
    'tracking_level': 'beginner',
    'country_code': 'HR',
    'settlement_enabled': false,
  };
}

Map<String, dynamic> vehicleRow({
  required String id,
  required String nickname,
  String householdId = 'h1',
  bool archived = false,
}) {
  return {
    'id': id,
    'household_id': householdId,
    'nickname': nickname,
    'fuel_type_key': 'fuel_diesel',
    'baseline_odometer_km': 50000,
    'baseline_date': '2026-01-01',
    'archived': archived,
  };
}

void main() {
  group('garageBootstrapFromRows', () {
    test('reads the households out of the embedded select', () {
      final bootstrap = garageBootstrapFromRows(
        households: [
          householdRow(id: 'h1', name: 'Hrvačić'),
          householdRow(id: 'h2', name: 'Radionica'),
        ],
        vehicles: const [],
      );

      expect(bootstrap.households.map((it) => it.id), ['h1', 'h2']);
      expect(bootstrap.households.first.name, 'Hrvačić');
    });

    test('keeps each household its own vehicles', () {
      final bootstrap = garageBootstrapFromRows(
        households: [
          householdRow(id: 'h1'),
          householdRow(id: 'h2'),
        ],
        vehicles: [
          vehicleRow(id: 'v1', nickname: 'Octavia'),
          vehicleRow(id: 'v2', nickname: 'Transit', householdId: 'h2'),
        ],
      );

      expect(bootstrap.vehiclesFor('h1').map((it) => it.id), ['v1']);
      expect(bootstrap.vehiclesFor('h2').map((it) => it.id), ['v2']);
    });

    test('sorts vehicles by nickname, ignoring case', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow()],
        vehicles: [
          vehicleRow(id: 'v1', nickname: 'zastava'),
          vehicleRow(id: 'v2', nickname: 'Octavia'),
          vehicleRow(id: 'v3', nickname: 'aixam'),
        ],
      );

      expect(bootstrap.vehiclesFor('h1').map((it) => it.nickname), [
        'aixam',
        'Octavia',
        'zastava',
      ]);
    });

    test('carries archived vehicles too, so the callers can filter', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow()],
        vehicles: [
          vehicleRow(id: 'v1', nickname: 'Octavia'),
          vehicleRow(id: 'v2', nickname: 'Punto', archived: true),
        ],
      );

      expect(bootstrap.vehiclesFor('h1').length, 2);
    });

    test(
      'a garage with no vehicles yields an empty list, not a missing one',
      () {
        final bootstrap = garageBootstrapFromRows(
          households: [householdRow()],
          vehicles: const [],
        );

        expect(bootstrap.vehiclesFor('h1'), isEmpty);
      },
    );

    test('an unknown or null household has no vehicles', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow()],
        vehicles: [vehicleRow(id: 'v1', nickname: 'Octavia')],
      );

      expect(bootstrap.vehiclesFor('nope'), isEmpty);
      expect(bootstrap.vehiclesFor(null), isEmpty);
    });

    test('no rows is the signed-out and not-yet-joined case', () {
      expect(
        garageBootstrapFromRows(
          households: const [],
          vehicles: const [],
        ).households,
        isEmpty,
      );
      expect(GarageBootstrap.empty.households, isEmpty);
    });

    test("carries the caller's role in each garage", () {
      final bootstrap = garageBootstrapFromRows(
        households: [
          householdRow(id: 'h1'),
          householdRow(id: 'h2'),
        ],
        vehicles: const [],
        memberships: [
          {'household_id': 'h1', 'role': 'driver'},
          {'household_id': 'h2', 'role': 'admin'},
        ],
      );

      expect(bootstrap.roleIn('h1'), 'driver');
      expect(bootstrap.roleIn('h2'), 'admin');
      expect(
        bootstrap.roleIn('h3'),
        'member',
        reason: 'a garage the fetch said nothing about is an ordinary one',
      );
    });

    test('a fetch that said nothing about roles reads as members', () {
      // What every garage was before roles were fetched, and what a cache
      // written before them still says.
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow(id: 'h1')],
        vehicles: const [],
      );

      expect(bootstrap.roleIn('h1'), 'member');
      expect(bootstrap.roleIn(null), 'member');
      expect(GarageBootstrap.empty.roleIn('h1'), 'member');
    });

    test('a membership row without a role is an ordinary member', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow(id: 'h1')],
        vehicles: const [],
        memberships: [
          {'household_id': 'h1'},
        ],
      );

      expect(bootstrap.roleIn('h1'), 'member');
    });
  });

  group('a car somebody lent you', () {
    // A guest pass opens one vehicle that belongs to a garage the holder is
    // not a member of. RLS returns it; the old fetch asked for households with
    // their vehicles nested, so it never came back and the feature was
    // invisible in the app.
    test('comes back even though its garage is not yours', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow(id: 'h1')],
        vehicles: [
          vehicleRow(id: 'v1', nickname: 'My Golf'),
          vehicleRow(id: 'v9', nickname: 'Sister Clio', householdId: 'hers'),
        ],
      );

      expect(bootstrap.borrowedVehicles.map((it) => it.id), ['v9']);
    });

    test('and is kept out of the garage it is not in', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow(id: 'h1')],
        vehicles: [
          vehicleRow(id: 'v1', nickname: 'My Golf'),
          vehicleRow(id: 'v9', nickname: 'Sister Clio', householdId: 'hers'),
        ],
      );

      expect(bootstrap.vehiclesFor('h1').map((it) => it.id), ['v1']);
    });

    test('borrowed cars are sorted like any other', () {
      final bootstrap = garageBootstrapFromRows(
        households: const [],
        vehicles: [
          vehicleRow(id: 'v2', nickname: 'zastava', householdId: 'hers'),
          vehicleRow(id: 'v1', nickname: 'Aixam', householdId: 'theirs'),
        ],
      );

      expect(bootstrap.borrowedVehicles.map((it) => it.nickname), [
        'Aixam',
        'zastava',
      ]);
    });

    test('nothing borrowed is an empty list, not a surprise', () {
      final bootstrap = garageBootstrapFromRows(
        households: [householdRow(id: 'h1')],
        vehicles: [vehicleRow(id: 'v1', nickname: 'My Golf')],
      );

      expect(bootstrap.borrowedVehicles, isEmpty);
      expect(GarageBootstrap.empty.borrowedVehicles, isEmpty);
    });
  });
}
