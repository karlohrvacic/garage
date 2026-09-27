import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';

void main() {
  group('the order a person picks a category in', () {
    test('puts what is paid every week ahead of what is paid every year', () {
      final order = CostCategories.byFrequency;
      expect(order.first, CostCategories.parking);
      expect(
        order.indexOf(CostCategories.toll),
        lessThan(order.indexOf(CostCategories.registration)),
      );
      expect(order.last, CostCategories.other);
    });

    test('offers every category, each once', () {
      expect(CostCategories.byFrequency, unorderedEquals(CostCategories.all));
      expect(
        CostCategories.byFrequency.toSet(),
        hasLength(CostCategories.byFrequency.length),
      );
    });
  });
}
