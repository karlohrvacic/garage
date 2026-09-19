import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/company/money_entry.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/company/reimbursements.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';

MoneyEntry money(
  String id, {
  required DateTime on,
  double amount = 10,
  PaymentMethod? paidWith = PaymentMethod.ownMoney,
  DateTime? reimbursedAt,
  String vehicleId = 'v1',
}) {
  return MoneyEntry(
    kind: MoneyEntryKind.cost,
    id: id,
    vehicleId: vehicleId,
    date: on,
    amount: amount,
    paidWith: paidWith,
    reimbursedAt: reimbursedAt,
  );
}

final log = [
  VehicleAssignment(
    id: 'a1',
    vehicleId: 'v1',
    userId: 'ana',
    fromDate: DateTime.utc(2026, 8, 1),
    toDate: DateTime.utc(2026, 8, 31),
  ),
  VehicleAssignment(
    id: 'a2',
    vehicleId: 'v1',
    userId: 'marko',
    fromDate: DateTime.utc(2026, 9, 1),
  ),
];

void main() {
  test('the three entry kinds become money entries, amounts and all', () {
    final entries = MoneyEntries.of(
      fuel: [
        FuelEntry(
          id: 'f1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 9, 2),
          odometerKm: 1,
          volumeL: 40,
          total: 62,
          fullTank: true,
          missedFill: false,
          createdBy: 'u1',
          paidWith: PaymentMethod.companyCard,
        ),
        // No total: nothing to pay back, whatever the method says.
        FuelEntry(
          id: 'f2',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 9, 3),
          odometerKm: 2,
          volumeL: 40,
          fullTank: true,
          missedFill: false,
          createdBy: 'u1',
          paidWith: PaymentMethod.ownMoney,
        ),
      ],
      services: [
        ServiceEntry(
          id: 's1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 9, 4),
          odometerKm: 3,
          serviceTypeKeys: const ['service_oil_change'],
          createdBy: 'u1',
          cost: 120,
          paidWith: PaymentMethod.ownMoney,
        ),
        // No cost: a job done at home, with nothing to pay back either.
        ServiceEntry(
          id: 's2',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 9, 6),
          odometerKm: 4,
          serviceTypeKeys: const ['service_oil_change'],
          createdBy: 'u1',
          diy: true,
          paidWith: PaymentMethod.ownMoney,
        ),
      ],
      costs: [
        CostEntry(
          id: 'c1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 9, 5),
          category: CostCategories.parking,
          amount: 4,
          createdBy: 'u1',
        ),
      ],
    );

    expect(entries.map((e) => '${e.kind.key}:${e.id}:${e.amount}'), [
      'fuel:f1:62.0',
      'service:s1:120.0',
      'cost:c1:4.0',
    ]);
    expect(entries.map((e) => e.kind.table).toSet(), {
      'fuel_entries',
      'service_entries',
      'cost_entries',
    });
  });

  test('own-money entries not yet paid back, per driver per month', () {
    final lines = Reimbursements.outstanding(
      entries: [
        money('c1', on: DateTime.utc(2026, 8, 10), amount: 20),
        money('c2', on: DateTime.utc(2026, 8, 20), amount: 5),
        money('c3', on: DateTime.utc(2026, 9, 2), amount: 12),
        money(
          'paid',
          on: DateTime.utc(2026, 9, 3),
          reimbursedAt: DateTime.utc(2026, 9, 10),
        ),
        money(
          'card',
          on: DateTime.utc(2026, 9, 4),
          paidWith: PaymentMethod.companyCard,
        ),
        money('cash', on: DateTime.utc(2026, 9, 4), paidWith: null),
      ],
      assignments: log,
    );

    expect(
      lines.map((l) => '${l.driverId}:${l.month.month}:${l.total}'),
      ['marko:9:12.0', 'ana:8:25.0'],
      reason: 'newest month first; paid, card and unrecorded left out',
    );
    expect(lines.last.entries.map((e) => e.id), ['c1', 'c2']);
  });

  test('a day nobody had the car is its own line, not somebody\'s', () {
    final lines = Reimbursements.outstanding(
      entries: [money('c1', on: DateTime.utc(2026, 7, 10))],
      assignments: log,
    );

    expect(lines.single.driverId, isNull);
  });
}
