import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';

Vehicle vehicle({
  String nickname = 'Golf',
  int baselineOdometerKm = 180000,
  String? make = 'VW',
  double? tankCapacityL = 55,
  bool archived = false,
}) {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: nickname,
    fuelTypeKey: 'fuel_petrol',
    baselineOdometerKm: baselineOdometerKm,
    baselineDate: DateTime.utc(2026, 1, 1),
    make: make,
    model: 'Golf VII',
    year: 2015,
    trim: 'Highline',
    vin: 'WVWZZZ1KZAW000001',
    plate: 'ZG1234AB',
    photoUrl: null,
    tankCapacityL: tankCapacityL,
    archived: archived,
  );
}

ServiceEntry service({
  List<String>? serviceTypeKeys,
  int odometerKm = 120000,
  double? cost = 210.5,
  String? notes,
}) {
  return ServiceEntry(
    id: 's1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 3, 4),
    odometerKm: odometerKm,
    serviceTypeKeys: serviceTypeKeys ?? ['service_oil_change'],
    createdBy: 'u1',
    cost: cost,
    shop: 'Auto Hrvoje',
    notes: notes,
  );
}

ReminderRule rule({
  int? intervalKm = 15000,
  int? intervalMonths = 12,
  bool active = true,
}) {
  return ReminderRule(
    id: 'r1',
    vehicleId: 'v1',
    serviceTypeKey: 'service_oil_change',
    intervalKm: intervalKm,
    intervalMonths: intervalMonths,
    active: active,
  );
}

Household household({
  String name = 'Hrvačić',
  String currencyCode = 'EUR',
  int bundlingWindowDays = 21,
  String trackingLevel = 'beginner',
}) {
  return Household(
    id: 'h1',
    name: name,
    currencyCode: currencyCode,
    bundlingWindowDays: bundlingWindowDays,
    trackingLevel: trackingLevel,
  );
}

void main() {
  group('Household equality', () {
    test('field-identical instances are equal and share a hash code', () {
      expect(household(), household());
      expect(household().hashCode, household().hashCode);
    });

    test('a differing name breaks equality', () {
      expect(household(name: 'Other'), isNot(household()));
    });

    test('a differing currency breaks equality', () {
      expect(household(currencyCode: 'USD'), isNot(household()));
    });

    test('a differing bundling window breaks equality', () {
      expect(household(bundlingWindowDays: 30), isNot(household()));
    });

    test('a differing tracking level breaks equality', () {
      expect(household(trackingLevel: 'advanced'), isNot(household()));
    });

    test('toString names the type and the fields', () {
      expect(household().toString(), contains('Household('));
      expect(household().toString(), contains('Hrvačić'));
    });
  });

  group('Vehicle equality', () {
    test('field-identical instances are equal and share a hash code', () {
      expect(vehicle(), vehicle());
      expect(vehicle().hashCode, vehicle().hashCode);
    });

    test('a differing nickname breaks equality', () {
      expect(vehicle(nickname: 'Passat'), isNot(vehicle()));
    });

    test('a differing baseline odometer breaks equality', () {
      expect(vehicle(baselineOdometerKm: 5), isNot(vehicle()));
    });

    test('a differing nullable field breaks equality', () {
      expect(vehicle(make: null), isNot(vehicle()));
    });

    test('a differing archived flag breaks equality', () {
      expect(vehicle(archived: true), isNot(vehicle()));
    });

    test('a differing tank capacity breaks equality', () {
      expect(vehicle(tankCapacityL: 60), isNot(vehicle()));
      expect(vehicle(tankCapacityL: null), isNot(vehicle()));
    });

    test('copyWith result equals a directly built twin', () {
      expect(
        vehicle().copyWith(nickname: 'Passat'),
        vehicle(nickname: 'Passat'),
      );
    });

    test('toString names the type and the fields', () {
      expect(vehicle().toString(), startsWith('Vehicle('));
      expect(vehicle().toString(), contains('nickname: Golf'));
    });
  });

  group('ServiceEntry equality', () {
    test('field-identical instances are equal and share a hash code', () {
      expect(service(), service());
      expect(service().hashCode, service().hashCode);
    });

    test('equal but non-identical serviceTypeKeys still compare equal', () {
      final left = ['service_oil_change', 'service_brake_pads'];
      final right = ['service_oil_change', 'service_brake_pads'];

      expect(identical(left, right), isFalse);
      expect(service(serviceTypeKeys: left), service(serviceTypeKeys: right));
      expect(
        service(serviceTypeKeys: left).hashCode,
        service(serviceTypeKeys: right).hashCode,
      );
    });

    test('differing serviceTypeKeys break equality', () {
      expect(
        service(serviceTypeKeys: ['service_oil_change']),
        isNot(service(serviceTypeKeys: ['service_brake_pads'])),
      );
    });

    test('a longer serviceTypeKeys list breaks equality', () {
      expect(
        service(serviceTypeKeys: ['service_oil_change']),
        isNot(
          service(
            serviceTypeKeys: ['service_oil_change', 'service_brake_pads'],
          ),
        ),
      );
    });

    test('serviceTypeKeys order is significant', () {
      expect(
        service(serviceTypeKeys: ['service_oil_change', 'service_brake_pads']),
        isNot(
          service(
            serviceTypeKeys: ['service_brake_pads', 'service_oil_change'],
          ),
        ),
      );
    });

    test('a differing odometer reading breaks equality', () {
      expect(service(odometerKm: 1), isNot(service()));
    });

    test('a differing nullable field breaks equality', () {
      expect(service(cost: null), isNot(service()));
      expect(service(notes: 'under warranty'), isNot(service()));
    });

    test('toString names the type and the fields', () {
      expect(service().toString(), startsWith('ServiceEntry('));
      expect(service().toString(), contains('service_oil_change'));
    });
  });

  group('ReminderRule equality', () {
    test('field-identical instances are equal and share a hash code', () {
      expect(rule(), rule());
      expect(rule().hashCode, rule().hashCode);
    });

    test('a differing distance interval breaks equality', () {
      expect(rule(intervalKm: 30000), isNot(rule()));
    });

    test('a null interval differs from a set one', () {
      expect(rule(intervalMonths: null), isNot(rule()));
    });

    test('a differing active flag breaks equality', () {
      expect(rule(active: false), isNot(rule()));
    });

    test('copyWith result equals a directly built twin', () {
      expect(rule().copyWith(active: false), rule(active: false));
    });

    test('toString names the type and the fields', () {
      expect(rule().toString(), startsWith('ReminderRule('));
      expect(rule().toString(), contains('intervalKm: 15000'));
    });
  });
}
