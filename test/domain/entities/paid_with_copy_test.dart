import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';

/// "How was it paid" is the one field on an entry that an edit sets back to
/// nothing: a fill-up marked as own money and then corrected to the default
/// has to reach the row as null. A plain nullable parameter cannot tell
/// "leave it" from "clear it", so the three `copyWith`s take the sentinel
/// `Household.copyWith` and `Incident.copyWith` use.
void main() {
  final fuel = FuelEntry(
    id: 'f1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 9, 2),
    odometerKm: 1,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
    paidWith: PaymentMethod.ownMoney,
  );
  final cost = CostEntry(
    id: 'c1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 9, 2),
    category: 'parking',
    amount: 12,
    createdBy: 'u1',
    paidWith: PaymentMethod.ownMoney,
  );
  final service = ServiceEntry(
    id: 's1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 9, 2),
    odometerKm: 1,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: 'u1',
    paidWith: PaymentMethod.ownMoney,
  );

  group('a fill-up', () {
    test('keeps the method when not asked about it', () {
      expect(fuel.copyWith(notes: 'x').paidWith, PaymentMethod.ownMoney);
    });

    test('replaces it, and clears it', () {
      expect(
        fuel.copyWith(paidWith: PaymentMethod.companyCard).paidWith,
        PaymentMethod.companyCard,
      );
      expect(fuel.copyWith(paidWith: null).paidWith, isNull);
    });
  });

  group('a cost', () {
    test('keeps the method when not asked about it', () {
      expect(cost.copyWith(amount: 13).paidWith, PaymentMethod.ownMoney);
    });

    test('replaces it, and clears it', () {
      expect(
        cost.copyWith(paidWith: PaymentMethod.companyCash).paidWith,
        PaymentMethod.companyCash,
      );
      expect(cost.copyWith(paidWith: null).paidWith, isNull);
    });
  });

  group('a service', () {
    test('keeps the method when not asked about it', () {
      expect(
        service.copyWith(vehicleId: 'v2').paidWith,
        PaymentMethod.ownMoney,
      );
    });

    test('replaces it, and clears it', () {
      expect(
        service.copyWith(paidWith: PaymentMethod.companyCard).paidWith,
        PaymentMethod.companyCard,
      );
      expect(service.copyWith(paidWith: null).paidWith, isNull);
    });
  });
}
