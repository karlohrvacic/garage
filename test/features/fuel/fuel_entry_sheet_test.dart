import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/fuel/widgets/fuel_entry_sheet.dart';

void main() {
  group('deriveMissingValue', () {
    test('fills in the total from volume and price', () {
      final result = deriveMissingValue(volume: '40', price: '1.5', total: '');

      expect(result.total, closeTo(60, 0.0001));
      expect(result.isComplete, isTrue);
    });

    test('fills in the price from volume and total', () {
      final result = deriveMissingValue(volume: '40', price: '', total: '60');

      expect(result.pricePerUnit, closeTo(1.5, 0.0001));
    });

    test('fills in the volume from price and total', () {
      final result = deriveMissingValue(volume: '', price: '1.5', total: '60');

      expect(result.volume, closeTo(40, 0.0001));
    });

    test('is incomplete with only one value', () {
      final result = deriveMissingValue(volume: '40', price: '', total: '');

      expect(result.isComplete, isFalse);
    });

    test('keeps all three when the user typed all three', () {
      final result = deriveMissingValue(volume: '40', price: '1.5', total: '61');

      expect(result.total, closeTo(61, 0.0001));
      expect(result.isComplete, isTrue);
    });

    test('accepts a comma decimal separator', () {
      final result = deriveMissingValue(volume: '40,5', price: '1,5', total: '');

      expect(result.volume, closeTo(40.5, 0.0001));
    });
  });
}
