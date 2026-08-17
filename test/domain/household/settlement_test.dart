import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/household/settlement.dart';

void main() {
  group('what each member has put in', () {
    test('a household where one person paid for everything', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 300, 'u2': 0},
      );

      expect(settlement.total, 300);
      expect(settlement.fairShare, 150);
      expect(settlement.balanceFor('u1'), 150);
      expect(settlement.balanceFor('u2'), -150);
    });

    test('a household that already splits evenly owes nothing', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 150, 'u2': 150},
      );

      expect(settlement.isSettled, isTrue);
      expect(settlement.transfers, isEmpty);
    });

    test('a member who spent nothing still counts toward the share', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 300, 'u2': 0, 'u3': 0},
      );

      expect(settlement.fairShare, 100);
      expect(settlement.balanceFor('u2'), -100);
    });

    test('an empty household has nothing to settle', () {
      final settlement = Settlement.of(spendByMember: const {});

      expect(settlement.total, 0);
      expect(settlement.fairShare, 0);
      expect(settlement.isSettled, isTrue);
      expect(settlement.transfers, isEmpty);
    });

    test('a member nobody logged anything for reads as zero, not missing', () {
      final settlement = Settlement.of(spendByMember: const {'u1': 0, 'u2': 0});

      expect(settlement.balanceFor('u1'), 0);
      expect(settlement.balanceFor('unknown'), 0);
    });
  });

  group('settling up', () {
    test('the one who paid less pays the one who paid more', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 300, 'u2': 0},
      );

      expect(settlement.transfers, hasLength(1));
      expect(settlement.transfers.single.from, 'u2');
      expect(settlement.transfers.single.to, 'u1');
      expect(settlement.transfers.single.amount, 150);
    });

    test('two debtors settle with one creditor', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 300, 'u2': 0, 'u3': 0},
      );

      expect(settlement.transfers, hasLength(2));
      expect(
        settlement.transfers.map((t) => t.amount),
        everyElement(closeTo(100, 0.001)),
      );
      expect(settlement.transfers.every((t) => t.to == 'u1'), isTrue);
    });

    test('a debtor can settle across two creditors', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 200, 'u2': 100, 'u3': 0},
      );

      // Fair share is 100: u1 is owed 100, u2 is square, u3 owes 100.
      expect(settlement.transfers, hasLength(1));
      expect(settlement.transfers.single.from, 'u3');
      expect(settlement.transfers.single.to, 'u1');
      expect(settlement.transfers.single.amount, closeTo(100, 0.001));
    });

    test('every transfer moves money from a debtor to a creditor', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 500, 'u2': 250, 'u3': 100, 'u4': 0},
      );

      for (final transfer in settlement.transfers) {
        expect(settlement.balanceFor(transfer.from), lessThan(0));
        expect(settlement.balanceFor(transfer.to), greaterThan(0));
      }
    });

    test('the transfers exactly clear every balance', () {
      final settlement = Settlement.of(
        spendByMember: const {'u1': 500, 'u2': 250, 'u3': 100, 'u4': 0},
      );

      final cleared = <String, double>{
        for (final id in settlement.members) id: settlement.balanceFor(id),
      };
      for (final transfer in settlement.transfers) {
        cleared[transfer.from] = cleared[transfer.from]! + transfer.amount;
        cleared[transfer.to] = cleared[transfer.to]! - transfer.amount;
      }

      for (final balance in cleared.values) {
        expect(balance, closeTo(0, 0.001));
      }
    });

    test('rounding noise does not invent a transfer', () {
      // 100 split three ways leaves thirds of a cent behind.
      final settlement = Settlement.of(
        spendByMember: const {'u1': 33.34, 'u2': 33.33, 'u3': 33.33},
      );

      expect(settlement.isSettled, isTrue);
      expect(settlement.transfers, isEmpty);
    });
  });

  group('spend nobody can be settled with', () {
    // What a deleted account leaves behind. The money went into the cars, so
    // it is part of what the household has spent — but there is no longer
    // anyone to pay or be paid, so it cannot be a participant in the split.

    test('is kept apart from the people the split is between', () {
      final settlement = Settlement.of(
        spendByMember: {'alice': 300, 'bob': 0},
        unattributed: 300,
      );

      expect(settlement.unattributed, 300);
      expect(settlement.spendByMember.keys, ['alice', 'bob']);
    });

    test('does not become an extra mouth to divide the share by', () {
      // The bug: an unattributed bucket counted as a third participant, so the
      // fair share fell from 150 to 200 and neither Alice nor Bob owed what
      // they actually owed.
      final settlement = Settlement.of(
        spendByMember: {'alice': 300, 'bob': 0},
        unattributed: 300,
      );

      expect(settlement.fairShare, 150);
    });

    test('never appears as somebody to pay', () {
      final settlement = Settlement.of(
        spendByMember: {'alice': 300, 'bob': 0},
        unattributed: 300,
      );

      expect(settlement.transfers, hasLength(1));
      expect(settlement.transfers.single.from, 'bob');
      expect(settlement.transfers.single.to, 'alice');
      expect(settlement.transfers.single.amount, 150);
    });

    test('leaves the balance between the living exactly as it was', () {
      // Sunk money benefits everyone equally, so it cannot move who owes whom.
      final withGhost = Settlement.of(
        spendByMember: {'alice': 300, 'bob': 0},
        unattributed: 9999,
      );
      final without = Settlement.of(spendByMember: {'alice': 300, 'bob': 0});

      expect(
        withGhost.transfers.single.amount,
        without.transfers.single.amount,
      );
    });

    test('still counts toward what the household has spent overall', () {
      final settlement = Settlement.of(
        spendByMember: {'alice': 300, 'bob': 0},
        unattributed: 300,
      );

      expect(settlement.total, 300, reason: 'the part being split');
      expect(settlement.householdTotal, 600, reason: 'everything that went in');
    });

    test('is zero for the ordinary household, and shows nothing', () {
      final settlement = Settlement.of(spendByMember: {'alice': 10, 'bob': 10});

      expect(settlement.unattributed, 0);
      expect(settlement.householdTotal, settlement.total);
    });

    test('a household with only unattributed spend has nothing to settle', () {
      // Everyone who ever logged anything has deleted their account.
      final settlement = Settlement.of(
        spendByMember: const {},
        unattributed: 300,
      );

      expect(settlement.transfers, isEmpty);
      expect(settlement.householdTotal, 300);
    });
  });
}
