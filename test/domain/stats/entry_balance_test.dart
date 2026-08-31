import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stats/entry_balance.dart';

LedgerEntry spent(double amount) => (amount: amount, isIncome: false);
LedgerEntry earned(double amount) => (amount: amount, isIncome: true);
const LedgerEntry noMoney = (amount: null, isIncome: false);

void main() {
  group('what a month came to', () {
    test('spending alone is negative, because it left', () {
      final balance = balanceOf([spent(62.40), spent(3)]);

      expect(balance.net, closeTo(-65.40, 1e-9));
      expect(balance.transactions, 2);
    });

    test('income alone is positive', () {
      final balance = balanceOf([earned(180)]);

      expect(balance.net, 180);
      expect(balance.transactions, 1);
    });

    test('a taxi month can end up ahead', () {
      final balance = balanceOf([spent(62.40), earned(180)]);

      expect(balance.net, closeTo(117.60, 1e-9));
    });

    test('nothing at all is nothing, not a division by zero', () {
      final balance = balanceOf([]);

      expect(balance.net, 0);
      expect(balance.transactions, 0);
    });
  });

  group('what does not count as a transaction', () {
    test('an odometer reading or a trip, which carry no money', () {
      final balance = balanceOf([spent(20), noMoney, noMoney]);

      expect(balance.net, -20);
      expect(
        balance.transactions,
        1,
        reason: 'a row is not a transaction just because it is a row',
      );
    });

    test('a fill-up whose total was never filled in', () {
      final balance = balanceOf([(amount: null, isIncome: false), spent(50)]);

      expect(balance.net, -50);
      expect(balance.transactions, 1);
    });

    test('a list of nothing but readings has no balance to show', () {
      final balance = balanceOf([noMoney, noMoney]);

      expect(balance.transactions, 0);
      expect(balance.isEmpty, isTrue);
    });
  });

  group('which way the money went', () {
    test('a month that spent more than it earned reads as spent', () {
      expect(balanceOf([spent(100), earned(40)]).spent, isTrue);
    });

    test('a month that earned more reads as received', () {
      expect(balanceOf([spent(40), earned(100)]).spent, isFalse);
    });

    test('a month that broke even exactly reads as spent, not as income', () {
      final balance = balanceOf([spent(100), earned(100)]);

      expect(balance.net, 0);
      expect(
        balance.spent,
        isTrue,
        reason: '"received €0.00" claims money arrived when none did',
      );
    });

    test('the amount to print is the size of it, without the sign', () {
      expect(balanceOf([spent(100), earned(40)]).magnitude, 60);
      expect(balanceOf([spent(40), earned(100)]).magnitude, 60);
    });
  });
}
