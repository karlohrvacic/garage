import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/format/amount_expression.dart';

void main() {
  group('a plain number is still a plain number', () {
    test('reads a decimal point', () {
      expect(evaluateAmount('12.50'), 12.5);
    });

    test('reads a decimal comma, the Croatian way of writing it', () {
      expect(evaluateAmount('12,50'), 12.5);
    });

    test('tolerates the spaces a thumb leaves behind', () {
      expect(evaluateAmount('  12.50  '), 12.5);
    });

    test('an empty field is not zero, it is nothing', () {
      expect(evaluateAmount(''), isNull);
      expect(evaluateAmount('   '), isNull);
    });
  });

  group('arithmetic', () {
    test('multiplies, which is the whole point: a second hour of parking', () {
      expect(evaluateAmount('2*1.50'), 3);
    });

    test('adds, for the receipt you split in your head', () {
      expect(evaluateAmount('12.50+7.20'), closeTo(19.7, 1e-9));
    });

    test('subtracts', () {
      expect(evaluateAmount('20-7.50'), 12.5);
    });

    test('divides', () {
      expect(evaluateAmount('30/4'), 7.5);
    });

    test('keeps the decimal comma decimal, never a separator', () {
      expect(evaluateAmount('2*1,50'), 3);
    });

    test('accepts the keypad glyphs the operator row inserts', () {
      expect(evaluateAmount('2×1.50'), 3);
      expect(evaluateAmount('30÷4'), 7.5);
    });

    test('ignores spaces around operators', () {
      expect(evaluateAmount('2 * 1.50'), 3);
    });

    test('chains left to right', () {
      expect(evaluateAmount('1+2+3'), 6);
      expect(evaluateAmount('20-5-5'), 10);
    });

    test('multiplication binds tighter than addition', () {
      expect(evaluateAmount('1+2*3'), 7);
      expect(evaluateAmount('2*3+1'), 7);
    });

    test('division binds tighter than subtraction', () {
      expect(evaluateAmount('10-6/2'), 7);
    });

    test('a leading minus is a sign, not a missing left operand', () {
      expect(evaluateAmount('-5'), -5);
      expect(evaluateAmount('-5+2'), -3);
    });
  });

  group('what the field must refuse', () {
    test('a dangling operator', () {
      expect(evaluateAmount('2*'), isNull);
      expect(evaluateAmount('2+'), isNull);
    });

    test('two operators in a row', () {
      expect(evaluateAmount('1//2'), isNull);
      expect(evaluateAmount('1*/2'), isNull);
    });

    test('a missing left operand that is not a sign', () {
      expect(evaluateAmount('*2'), isNull);
      expect(evaluateAmount('/2'), isNull);
    });

    test('letters', () {
      expect(evaluateAmount('12 eur'), isNull);
      expect(evaluateAmount('abc'), isNull);
    });

    test('division by zero, rather than infinity in the amount column', () {
      expect(evaluateAmount('5/0'), isNull);
      expect(evaluateAmount('5/0.0'), isNull);
    });

    test('a number with two decimal marks', () {
      expect(evaluateAmount('1.2.3'), isNull);
      expect(evaluateAmount('1,2,3'), isNull);
    });

    test('parentheses, which this evaluator deliberately does not do', () {
      expect(evaluateAmount('(1+2)*3'), isNull);
    });
  });

  group(
    'isAmountExpression, which decides whether to show the result line',
    () {
      test('a plain number needs no echo', () {
        expect(isAmountExpression('12.50'), isFalse);
        expect(isAmountExpression('12,50'), isFalse);
        expect(isAmountExpression(''), isFalse);
      });

      test('a leading minus alone is not arithmetic worth echoing', () {
        expect(isAmountExpression('-5'), isFalse);
      });

      test('an operator between operands is', () {
        expect(isAmountExpression('2*1.50'), isTrue);
        expect(isAmountExpression('12.50+7.20'), isTrue);
        expect(isAmountExpression('20-7.50'), isTrue);
        expect(isAmountExpression('30÷4'), isTrue);
      });

      test(
        'a half-typed expression still counts, so the line can go quiet',
        () {
          expect(isAmountExpression('2*'), isTrue);
        },
      );
    },
  );
}
