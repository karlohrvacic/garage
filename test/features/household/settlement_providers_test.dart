import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/features/household/providers/settlement_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

Vehicle vehicle(String id) {
  return Vehicle(
    id: id,
    householdId: 'h1',
    nickname: id,
    fuelTypeKey: 'fuel_petrol',
    baselineOdometerKm: 0,
    baselineDate: DateTime.utc(2026, 1, 1),
  );
}

FuelEntry fill(String id, String createdBy, {double? total = 60}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 5, 1),
    odometerKm: 50000,
    volumeL: 40,
    total: total,
    fullTank: true,
    missedFill: false,
    createdBy: createdBy,
  );
}

ServiceEntry service(String id, String createdBy, {double? cost = 200}) {
  return ServiceEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 4, 2),
    odometerKm: 49000,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: createdBy,
    cost: cost,
  );
}

CostEntry cost(String id, String createdBy, {double amount = 100}) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 3, 1),
    category: CostCategories.insurance,
    amount: amount,
    createdBy: createdBy,
  );
}

ProviderContainer containerWith({
  List<HouseholdMember> members = const [
    HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
    HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
  ],
  List<FuelEntry> fuel = const [],
  List<ServiceEntry> services = const [],
  List<CostEntry> costs = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      vehiclesProvider.overrideWith((ref) async => [vehicle('v1')]),
      membersProvider.overrideWith((ref) async => members),
      rawFuelEntriesProvider('v1').overrideWith((ref) async => fuel),
      serviceEntriesProvider('v1').overrideWith((ref) async => services),
      costEntriesProvider('v1').overrideWith((ref) async => costs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a household that has logged nothing owes nothing', () async {
    final container = containerWith();

    final settlement = await container.read(settlementProvider.future);

    expect(settlement.total, 0);
    expect(settlement.isSettled, isTrue);
  });

  test('every kind of spend counts toward who paid', () async {
    final container = containerWith(
      fuel: [fill('f1', 'u1')],
      services: [service('s1', 'u1')],
      costs: [cost('c1', 'u2')],
    );

    final settlement = await container.read(settlementProvider.future);

    expect(settlement.spendByMember['u1'], 260);
    expect(settlement.spendByMember['u2'], 100);
    expect(settlement.total, 360);
  });

  test('a member who has logged nothing is still in the split', () async {
    final container = containerWith(fuel: [fill('f1', 'u1')]);

    final settlement = await container.read(settlementProvider.future);

    expect(settlement.spendByMember['u2'], 0);
    expect(settlement.fairShare, 30);
    expect(settlement.transfers.single.from, 'u2');
  });

  test('an entry with no recorded price adds nothing', () async {
    final container = containerWith(
      fuel: [fill('f1', 'u1', total: null)],
      services: [service('s1', 'u1', cost: null)],
    );

    final settlement = await container.read(settlementProvider.future);

    expect(settlement.total, 0);
  });

  test('spend from a member who has since left still counts', () async {
    // Their money went into the vehicles; dropping it would silently rewrite
    // what everyone else owes.
    final container = containerWith(
      members: const [
        HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
      ],
      fuel: [fill('f1', 'u1'), fill('f2', 'departed')],
    );

    final settlement = await container.read(settlementProvider.future);

    expect(settlement.spendByMember['departed'], 60);
    expect(settlement.total, 120);
  });

  group('spend logged by an account that has been deleted', () {
    // The row survives the deletion with a null author, which arrives here as
    // an empty string. It used to become a participant of its own.
    test('does not turn into a nameless member of the household', () async {
      final container = containerWith(fuel: [fill('f1', 'u1'), fill('f2', '')]);

      final settlement = await container.read(settlementProvider.future);

      expect(settlement.spendByMember.keys, ['u1', 'u2']);
      expect(settlement.unattributed, 60);
    });

    test('does not change what the living owe each other', () async {
      final withGhost = await containerWith(
        fuel: [fill('f1', 'u1'), fill('f2', '')],
      ).read(settlementProvider.future);
      final withoutGhost = await containerWith(
        fuel: [fill('f1', 'u1')],
      ).read(settlementProvider.future);

      expect(withGhost.fairShare, withoutGhost.fairShare);
      expect(withGhost.transfers.single.amount, 30);
    });

    test('still counts toward what the household has spent', () async {
      final container = containerWith(fuel: [fill('f1', 'u1'), fill('f2', '')]);

      final settlement = await container.read(settlementProvider.future);

      expect(settlement.householdTotal, 120);
    });
  });
}
