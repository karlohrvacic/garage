import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';

CostEntry entry({VignetteCountry? country, VignetteValidity? validity}) {
  return CostEntry(
    id: 'c1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 5, 23),
    category: CostCategories.vignette,
    amount: 16,
    createdBy: 'u1',
    vignetteCountry: country,
    vignetteValidity: validity,
  );
}

void main() {
  group('a vignette entry carries what it was bought for', () {
    test('null by default, for every category that is not a vignette', () {
      final cost = CostEntry(
        id: 'c1',
        vehicleId: 'v1',
        date: DateTime.utc(2026, 5, 23),
        category: CostCategories.parking,
        amount: 3,
        createdBy: 'u1',
      );

      expect(cost.vignetteCountry, isNull);
      expect(cost.vignetteValidity, isNull);
    });

    test('round-trips through the entity unchanged', () {
      final cost = entry(
        country: VignetteCountry.slovenia,
        validity: VignetteValidity.days7,
      );

      expect(cost.vignetteCountry, VignetteCountry.slovenia);
      expect(cost.vignetteValidity, VignetteValidity.days7);
    });

    test('copyWith replaces only what is named', () {
      final cost = entry(
        country: VignetteCountry.slovenia,
        validity: VignetteValidity.days7,
      );
      final renewed = cost.copyWith(vignetteValidity: VignetteValidity.days30);

      expect(renewed.vignetteCountry, VignetteCountry.slovenia);
      expect(renewed.vignetteValidity, VignetteValidity.days30);
    });

    test('equality includes both fields', () {
      final a = entry(
        country: VignetteCountry.slovenia,
        validity: VignetteValidity.days7,
      );
      final b = entry(
        country: VignetteCountry.austria,
        validity: VignetteValidity.days7,
      );

      expect(a, isNot(b));
      expect(
        a,
        entry(
          country: VignetteCountry.slovenia,
          validity: VignetteValidity.days7,
        ),
      );
    });
  });
}
