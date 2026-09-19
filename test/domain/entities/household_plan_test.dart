import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';

Household garage({
  String plan = 'free',
  DateTime? planUntil,
  String? companyName,
  String? companyOib,
  String? companyAddress,
}) {
  return Household(
    id: 'h1',
    name: 'Prijevoz',
    plan: plan,
    planUntil: planUntil,
    companyName: companyName,
    companyOib: companyOib,
    companyAddress: companyAddress,
  );
}

void main() {
  final now = DateTime.utc(2026, 9, 19);

  group('the plan', () {
    test('is free unless somebody said otherwise', () {
      expect(const Household(id: 'h1', name: 'Hrvačić').plan, 'free');
      expect(garage().isOnCompanyPlan, isFalse);
      expect(garage().companyEnabledAt(now), isFalse);
    });

    test('with no end is the company plan, enabled', () {
      expect(garage(plan: 'company').isOnCompanyPlan, isTrue);
      expect(garage(plan: 'company').companyEnabledAt(now), isTrue);
    });

    test('with an end ahead is enabled until then', () {
      final until = DateTime.utc(2027, 1, 1);

      expect(
        garage(plan: 'company', planUntil: until).companyEnabledAt(now),
        isTrue,
      );
      expect(
        garage(plan: 'company', planUntil: until).companyEnabledAt(until),
        isFalse,
        reason: 'the end is the first moment without the plan',
      );
    });

    test('lapsed keeps the word and loses what it gates', () {
      // Every screen stays on a lapsed garage (decision 155); only adding a
      // car above the cap, a driver and an assignment wait for the plan.
      final lapsed = garage(plan: 'company', planUntil: DateTime.utc(2026, 1));

      expect(lapsed.isOnCompanyPlan, isTrue);
      expect(lapsed.companyEnabledAt(now), isFalse);
      expect(lapsed.companyLapsedAt(now), isTrue);
    });

    test('is lapsed only when it was had and has ended', () {
      // What a screen asks before choosing between "the plan ended" and
      // the free cap: a free garage never had a plan to lose.
      expect(garage().companyLapsedAt(now), isFalse);
      expect(garage(plan: 'company').companyLapsedAt(now), isFalse);
      expect(
        garage(
          plan: 'company',
          planUntil: DateTime.utc(2027, 1, 1),
        ).companyLapsedAt(now),
        isFalse,
      );
    });
  });

  group('the free cap', () {
    // The same rule as can_add_vehicle (migration 0080): five active cars
    // on a free garage, and none on the plan. The insert policy applies it
    // with a bare permission error, so the app asks here first.
    test('lets a free garage grow to five cars and no further', () {
      expect(Household.freeVehicleLimit, 5);
      expect(garage().canAddVehicleAt(now, activeVehicles: 4), isTrue);
      expect(garage().canAddVehicleAt(now, activeVehicles: 5), isFalse);
      expect(garage().canAddVehicleAt(now, activeVehicles: 12), isFalse);
    });

    test('does not apply on the plan', () {
      expect(
        garage(plan: 'company').canAddVehicleAt(now, activeVehicles: 12),
        isTrue,
      );
    });

    test('applies again once the plan has lapsed, keeping what is there', () {
      final lapsed = garage(plan: 'company', planUntil: DateTime.utc(2026, 1));

      expect(lapsed.canAddVehicleAt(now, activeVehicles: 12), isFalse);
      expect(lapsed.canAddVehicleAt(now, activeVehicles: 3), isTrue);
    });

    // A restore or an import creates cars one after another, and the
    // database asks the cap before each insert: the check has to walk the
    // list the way the inserts would, before the first one lands.
    group('for several cars at once', () {
      test('admits what fits and refuses what would not', () {
        expect(
          garage().canAddVehiclesAt(
            now,
            activeVehicles: 3,
            archived: [false, false],
          ),
          isTrue,
        );
        expect(
          garage().canAddVehiclesAt(
            now,
            activeVehicles: 3,
            archived: [false, false, false],
          ),
          isFalse,
        );
        expect(
          garage().canAddVehiclesAt(
            now,
            activeVehicles: 0,
            archived: [for (var i = 0; i < 6; i++) false],
          ),
          isFalse,
          reason: 'a six-car backup into a fresh free garage',
        );
      });

      test('an archived car is checked but does not raise the count', () {
        // The insert of an archived car is refused by the same rule once
        // the garage is full, and admitted while it is not — and it never
        // makes the garage fuller.
        expect(
          garage().canAddVehiclesAt(
            now,
            activeVehicles: 4,
            archived: [true, true, false],
          ),
          isTrue,
        );
        expect(
          garage().canAddVehiclesAt(
            now,
            activeVehicles: 4,
            archived: [false, true],
          ),
          isFalse,
          reason: 'the archived one arrives at a garage already full',
        );
      });

      test('nothing to create is always fine, and the plan lifts it', () {
        expect(
          garage().canAddVehiclesAt(now, activeVehicles: 5, archived: []),
          isTrue,
        );
        expect(
          garage(plan: 'company').canAddVehiclesAt(
            now,
            activeVehicles: 12,
            archived: [false, false, false],
          ),
          isTrue,
        );
      });
    });
  });

  group('copyWith', () {
    test('leaves the plan alone, since nothing in the app writes it', () {
      final copied = garage(
        plan: 'company',
        planUntil: DateTime.utc(2027),
      ).copyWith(name: 'Renamed');

      expect(copied.plan, 'company');
      expect(copied.planUntil, DateTime.utc(2027));
      expect(copied.name, 'Renamed');
    });

    test('keeps the letterhead when not asked about it', () {
      final copied = garage(
        companyName: 'Prijevoz d.o.o.',
        companyOib: '12345678901',
        companyAddress: 'Ilica 1',
      ).copyWith(name: 'Renamed');

      expect(copied.companyName, 'Prijevoz d.o.o.');
      expect(copied.companyOib, '12345678901');
      expect(copied.companyAddress, 'Ilica 1');
    });

    test('can clear a letterhead field, which an empty OIB needs', () {
      // The console empties a field and the database has a check on the
      // OIB's shape, so what leaves the app has to be null, not ''.
      final cleared = garage(
        companyName: 'Prijevoz d.o.o.',
        companyOib: '12345678901',
        companyAddress: 'Ilica 1',
      ).copyWith(companyOib: null, companyAddress: null);

      expect(cleared.companyName, 'Prijevoz d.o.o.');
      expect(cleared.companyOib, isNull);
      expect(cleared.companyAddress, isNull);
    });
  });

  group('equality', () {
    test('a differing plan breaks equality', () {
      expect(garage(plan: 'company'), isNot(garage()));
      expect(
        garage(plan: 'company', planUntil: DateTime.utc(2027)),
        isNot(garage(plan: 'company')),
      );
    });

    test('a differing letterhead breaks equality', () {
      expect(garage(companyName: 'Prijevoz d.o.o.'), isNot(garage()));
      expect(garage(companyOib: '12345678901'), isNot(garage()));
      expect(garage(companyAddress: 'Ilica 1'), isNot(garage()));
    });

    test('toString says which plan the garage is on', () {
      expect(garage(plan: 'company').toString(), contains('plan: company'));
    });
  });
}
