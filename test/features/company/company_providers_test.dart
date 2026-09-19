import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/data/company_repository.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

/// The company repository as a screen test sees it: every call is recorded,
/// and what a read returns is set up front.
class RecordingCompanyRepository implements CompanyRepository {
  RecordingCompanyRepository({
    this.fleet = const [],
    this.own = const [],
    this.failWith,
    this.readFailsWith,
  });

  List<VehicleAssignment> fleet;
  List<VehicleAssignment> own;

  /// Thrown by every write, for a test about what a screen does with a
  /// refusal.
  AppFailure? failWith;

  /// Thrown by the read of the log, for a test about a first load that
  /// fails outright: the cache serves nothing, since nothing was ever read.
  AppFailure? readFailsWith;
  final List<String> calls = [];

  @override
  Future<List<VehicleAssignment>> assignmentsForVehicles(
    List<String> vehicleIds,
  ) async {
    calls.add('fleet:${vehicleIds.join(',')}');
    if (readFailsWith case final failure?) {
      throw failure;
    }
    return fleet;
  }

  @override
  Future<List<VehicleAssignment>> mine() async {
    calls.add('mine');
    if (readFailsWith case final failure?) {
      throw failure;
    }
    return own;
  }

  @override
  Future<String?> handOver({
    required String vehicleId,
    required DateTime on,
    int? odometerKm,
    String? toUserId,
    String? note,
  }) async {
    calls.add('handOver:$vehicleId:${toUserId ?? '-'}:$odometerKm');
    _refuse();
    return toUserId == null ? null : 'new';
  }

  @override
  Future<void> confirm(String assignmentId) async {
    calls.add('confirm:$assignmentId');
    _refuse();
    // Signed, as the row would be: the read after the invalidation returns
    // it confirmed, and the card that asked has nothing left to show.
    own = [
      for (final assignment in own)
        assignment.id == assignmentId
            ? assignment.copyWith(
                confirmedAt: DateTime.utc(2026, 9, 19, 8),
                confirmedBy: assignment.userId,
              )
            : assignment,
    ];
  }

  @override
  Future<void> deleteAssignment(String id) async {
    calls.add('delete:$id');
    _refuse();
  }

  @override
  Future<void> markReimbursed({
    required String table,
    required List<String> ids,
    required DateTime at,
  }) async {
    calls.add('reimbursed:$table:${ids.join(',')}');
    _refuse();
  }

  @override
  Future<void> requestReceiptReminder({
    required String vehicleId,
    required String kind,
    required String entryId,
    required String driverId,
  }) async {
    calls.add('remind:$kind:$entryId:$driverId');
    _refuse();
  }

  void _refuse() {
    if (failWith case final failure?) {
      throw failure;
    }
  }
}

const _company = Household(id: 'h1', name: 'Prijevoz', plan: 'company');
const _company2 = Household(id: 'h2', name: 'Dostava', plan: 'company');

VehicleAssignment window(
  String id, {
  String vehicleId = 'v1',
  String userId = 'u2',
  required DateTime from,
  DateTime? to,
  DateTime? confirmedAt,
}) {
  return VehicleAssignment(
    id: id,
    vehicleId: vehicleId,
    userId: userId,
    fromDate: from,
    toDate: to,
    confirmedAt: confirmedAt,
  );
}

void main() {
  // The bootstrap is an AsyncNotifier; overriding it with a value needs the
  // notifier form, so every container below builds its own. Both async
  // roots are awaited before the container is handed back: the plain
  // providers read their `.value`, which is null until they resolve.
  Future<ProviderContainer> scoped({
    Household? household = _company,
    String role = 'admin',
    RecordingCompanyRepository? repository,
    DateTime? now,
    List<Vehicle>? vehicles,
  }) async {
    final container = ProviderContainer(
      overrides: [
        currentHouseholdProvider.overrideWith((ref) async => household),
        currentUserIdProvider.overrideWithValue('u1'),
        garageBootstrapProvider.overrideWith(
          () => _FixedBootstrap(
            GarageBootstrap(
              households: [?household],
              vehiclesByHousehold: {
                if (household != null)
                  household.id:
                      vehicles ?? [testVehicle('v1'), testVehicle('v2')],
              },
              rolesByHousehold: {if (household != null) household.id: role},
            ),
          ),
        ),
        companyRepositoryProvider.overrideWithValue(
          repository ?? RecordingCompanyRepository(),
        ),
        memberNamesProvider.overrideWith(
          (ref) async => {'u1': 'Karlo', 'u2': 'Ana', 'u3': 'Ivo'},
        ),
        clockProvider.overrideWithValue(
          () => now ?? DateTime.utc(2026, 9, 19, 12),
        ),
        todayProvider.overrideWithValue(now ?? DateTime(2026, 9, 19)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentHouseholdProvider.future);
    await container.read(garageBootstrapProvider.future);
    return container;
  }

  group('the plan', () {
    test(
      'a private garage is off it, and asks the repository nothing',
      () async {
        final repository = RecordingCompanyRepository();
        final container = await scoped(
          household: testHousehold,
          repository: repository,
        );

        expect(container.read(companyPlanProvider), isFalse);
        expect(container.read(companyEnabledProvider), isFalse);
        expect(await container.read(fleetAssignmentsProvider.future), isEmpty);
        expect(repository.calls, isEmpty);
      },
    );

    test('a company garage is on it', () async {
      final container = await scoped();

      expect(container.read(companyPlanProvider), isTrue);
      expect(container.read(companyEnabledProvider), isTrue);
    });

    test('a lapsed one keeps the plan and loses the gate', () async {
      final container = await scoped(
        household: Household(
          id: 'h1',
          name: 'Prijevoz',
          plan: 'company',
          planUntil: DateTime.utc(2026, 9, 1),
        ),
      );

      expect(container.read(companyPlanProvider), isTrue);
      expect(container.read(companyEnabledProvider), isFalse);
    });

    test('no garage at all is off it', () async {
      final container = await scoped(household: null);

      expect(container.read(companyPlanProvider), isFalse);
      expect(container.read(companyEnabledProvider), isFalse);
      expect(container.read(companyConsoleVisibleProvider), isFalse);
    });
  });

  group('the free cap', () {
    // What the vehicles insert policy decides with can_add_vehicle
    // (migration 0080), asked before the form is offered: the policy's own
    // answer is a bare permission error.
    List<Vehicle> cars(int active, {int archived = 0}) => [
      for (var i = 0; i < active; i++) testVehicle('v$i'),
      for (var i = 0; i < archived; i++) testVehicle('old$i', archived: true),
    ];

    Future<bool> canAdd({
      Household household = _company,
      required List<Vehicle> vehicles,
    }) async {
      final container = await scoped(household: household, vehicles: vehicles);
      // Derived from the bootstrap, and async: the plain provider reads its
      // value, which is null until the list has resolved once.
      await container.read(vehiclesProvider.future);
      return container.read(canAddVehicleProvider);
    }

    test('a free garage takes a fifth car and refuses a sixth', () async {
      expect(await canAdd(household: testHousehold, vehicles: cars(4)), isTrue);
      expect(
        await canAdd(household: testHousehold, vehicles: cars(5)),
        isFalse,
      );
    });

    test('archived cars do not count', () async {
      expect(
        await canAdd(household: testHousehold, vehicles: cars(3, archived: 4)),
        isTrue,
      );
    });

    test('the plan lifts it, and a lapsed plan brings it back', () async {
      expect(await canAdd(vehicles: cars(12)), isTrue);
      expect(
        await canAdd(
          household: Household(
            id: 'h1',
            name: 'Prijevoz',
            plan: 'company',
            planUntil: DateTime.utc(2026, 9, 1),
          ),
          vehicles: cars(12),
        ),
        isFalse,
      );
    });

    test('while the list is still loading, the database decides', () async {
      final container = await scoped(
        household: testHousehold,
        vehicles: cars(5),
      );

      expect(container.read(canAddVehicleProvider), isTrue);
    });
  });

  group('the role', () {
    test('comes from the startup fetch', () async {
      expect((await scoped(role: 'driver')).read(myRoleProvider), 'driver');
      expect((await scoped(role: 'driver')).read(isDriverProvider), isTrue);
      expect((await scoped()).read(myRoleProvider), 'admin');
      expect((await scoped()).read(isDriverProvider), isFalse);
    });

    test('the console is an admin\'s, on the plan', () async {
      expect((await scoped()).read(companyConsoleVisibleProvider), isTrue);
      expect(
        (await scoped(role: 'member')).read(companyConsoleVisibleProvider),
        isFalse,
      );
      expect(
        (await scoped(role: 'driver')).read(companyConsoleVisibleProvider),
        isFalse,
      );
      expect(
        (await scoped(
          household: testHousehold,
        )).read(companyConsoleVisibleProvider),
        isFalse,
      );
    });

    test('a lapsed plan keeps the console', () async {
      // Decision 155: a lapsed garage keeps every screen; the console still
      // names who had which car.
      final container = await scoped(
        household: Household(
          id: 'h1',
          name: 'Prijevoz',
          plan: 'company',
          planUntil: DateTime.utc(2026, 9, 1),
        ),
      );

      expect(container.read(companyConsoleVisibleProvider), isTrue);
    });

    test(
      'on a car is the role in the car\'s garage, not the one on screen',
      () async {
        // A driver whose own private garage is the current one opens the
        // company's car by URL: the page has to ask about the car's garage.
        final container = ProviderContainer(
          overrides: [
            currentHouseholdProvider.overrideWith((ref) async => testHousehold),
            currentUserIdProvider.overrideWithValue('u1'),
            garageBootstrapProvider.overrideWith(
              () => _FixedBootstrap(
                GarageBootstrap(
                  households: const [testHousehold, _company2],
                  vehiclesByHousehold: {
                    'h1': [testVehicle('mine')],
                    'h2': [testVehicle('van', householdId: 'h2')],
                  },
                  rolesByHousehold: const {'h1': 'admin', 'h2': 'driver'},
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(garageBootstrapProvider.future);

        expect(container.read(isDriverProvider), isFalse);
        expect(container.read(roleForVehicleProvider('van')), 'driver');
        expect(container.read(isDriverForVehicleProvider('van')), isTrue);
        expect(container.read(roleForVehicleProvider('mine')), 'admin');
        expect(container.read(isDriverForVehicleProvider('mine')), isFalse);
        // A car the bootstrap does not list is nobody's to drive.
        expect(container.read(roleForVehicleProvider('stranger')), 'member');
      },
    );
  });

  group('the log', () {
    test('is read once for every car in the garage', () async {
      final repository = RecordingCompanyRepository(
        fleet: [window('a1', from: DateTime.utc(2026, 9, 1))],
      );
      final container = await scoped(repository: repository);

      final assignments = await container.read(fleetAssignmentsProvider.future);

      expect(assignments.map((it) => it.id), ['a1']);
      expect(repository.calls, ['fleet:v1,v2']);
    });

    test('a driver reads their own windows, nobody else asks', () async {
      final repository = RecordingCompanyRepository(
        own: [window('a1', from: DateTime.utc(2026, 9, 1))],
      );

      final driver = await scoped(role: 'driver', repository: repository);
      expect(await driver.read(myAssignmentsProvider.future), hasLength(1));
      expect(repository.calls, ['mine']);

      repository.calls.clear();
      final member = await scoped(repository: repository);
      expect(await member.read(myAssignmentsProvider.future), isEmpty);
      expect(repository.calls, isEmpty);
    });

    test(
      'a handover to confirm is an open, unconfirmed window of mine',
      () async {
        final repository = RecordingCompanyRepository(
          own: [
            window(
              'old',
              from: DateTime.utc(2026, 1, 1),
              to: DateTime.utc(2026, 8, 31),
            ),
            window('now', from: DateTime.utc(2026, 9, 1)),
            window('later', from: DateTime.utc(2026, 10, 1)),
            window(
              'signed',
              vehicleId: 'v2',
              from: DateTime.utc(2026, 9, 1),
              confirmedAt: DateTime.utc(2026, 9, 1, 9),
            ),
          ],
        );
        final container = await scoped(role: 'driver', repository: repository);

        final pending = await container.read(pendingHandoversProvider.future);

        expect(pending.map((it) => it.id), ['now']);
      },
    );
  });

  group('who had the car', () {
    final repository = RecordingCompanyRepository(
      fleet: [
        window(
          'a1',
          from: DateTime.utc(2026, 5, 1),
          to: DateTime.utc(2026, 5, 31),
        ),
        window('a2', userId: 'u3', from: DateTime.utc(2026, 6, 1)),
      ],
    );

    test('is resolved by the day, and named', () async {
      final container = await scoped(repository: repository);
      await container.read(fleetAssignmentsProvider.future);
      await container.read(memberNamesProvider.future);

      expect(
        container.read(
          driverOnProvider((vehicleId: 'v1', date: DateTime.utc(2026, 5, 15))),
        ),
        'u2',
      );
      expect(
        container.read(
          driverNameOnProvider((
            vehicleId: 'v1',
            date: DateTime.utc(2026, 7, 1),
          )),
        ),
        'Ivo',
      );
      expect(
        container.read(
          driverNameOnProvider((
            vehicleId: 'v1',
            date: DateTime.utc(2026, 4, 1),
          )),
        ),
        isNull,
      );
      expect(
        container.read(
          driverOnProvider((vehicleId: 'v2', date: DateTime.utc(2026, 5, 15))),
        ),
        isNull,
      );
    });

    test('is nobody while the log is still loading', () async {
      final container = await scoped(repository: repository);

      expect(
        container.read(
          driverOnProvider((vehicleId: 'v1', date: DateTime.utc(2026, 5, 15))),
        ),
        isNull,
      );
    });

    test('a driver the member list no longer names is a blank', () async {
      final container = await scoped(
        repository: RecordingCompanyRepository(
          fleet: [window('a1', userId: 'gone', from: DateTime.utc(2026, 5, 1))],
        ),
      );
      await container.read(fleetAssignmentsProvider.future);
      await container.read(memberNamesProvider.future);

      expect(
        container.read(
          driverNameOnProvider((
            vehicleId: 'v1',
            date: DateTime.utc(2026, 5, 15),
          )),
        ),
        '',
      );
    });
  });

  group('the controller', () {
    test('hands over and refreshes what a driver sees', () async {
      final repository = RecordingCompanyRepository();
      final container = await scoped(repository: repository);
      await container.read(fleetAssignmentsProvider.future);
      repository.calls.clear();

      final ok = await container
          .read(companyControllerProvider.notifier)
          .handOver(
            vehicleId: 'v1',
            on: DateTime(2026, 9, 19),
            odometerKm: 62000,
            toUserId: 'u2',
          );

      expect(ok, isTrue);
      expect(repository.calls.first, 'handOver:v1:u2:62000');
      await container.read(fleetAssignmentsProvider.future);
      expect(
        repository.calls,
        contains('fleet:v1,v2'),
        reason: 'the log is read again after a handover',
      );
    });

    test('confirms as the driver', () async {
      final repository = RecordingCompanyRepository();
      final container = await scoped(role: 'driver', repository: repository);
      await container.read(myAssignmentsProvider.future);
      repository.calls.clear();

      final ok = await container
          .read(companyControllerProvider.notifier)
          .confirm('a1');

      expect(ok, isTrue);
      expect(repository.calls.first, 'confirm:a1');
      await container.read(myAssignmentsProvider.future);
      expect(
        repository.calls,
        contains('mine'),
        reason: 'the handovers to confirm are read again',
      );
    });

    test('removes a window', () async {
      final repository = RecordingCompanyRepository();
      final container = await scoped(repository: repository);

      final ok = await container
          .read(companyControllerProvider.notifier)
          .removeAssignment(window('a1', from: DateTime.utc(2026, 9, 1)));

      expect(ok, isTrue);
      expect(repository.calls, ['delete:a1']);
    });

    test('a refusal is kept for the sheet, and the sheet stays open', () async {
      final repository = RecordingCompanyRepository(
        failWith: const AppFailure(kind: AppFailureKind.handoverClash),
      );
      final container = await scoped(repository: repository);

      final ok = await container
          .read(companyControllerProvider.notifier)
          .handOver(vehicleId: 'v1', on: DateTime(2026, 9, 19), toUserId: 'u2');

      expect(ok, isFalse);
      expect(
        container.read(companyControllerProvider).error,
        isA<AppFailure>().having(
          (it) => it.kind,
          'kind',
          AppFailureKind.handoverClash,
        ),
      );
    });
  });
}

class _FixedBootstrap extends GarageBootstrapNotifier {
  _FixedBootstrap(this.fixed);

  final GarageBootstrap fixed;

  @override
  Future<GarageBootstrap> build() async => fixed;
}
