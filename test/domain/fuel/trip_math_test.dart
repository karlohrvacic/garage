import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/trip_math.dart';

void main() {
  test('required fuel scales consumption over the distance', () {
    expect(
      TripMath.requiredFuel(distanceKm: 250, litersPer100Km: 6),
      closeTo(15, 0.001),
    );
  });

  test('trip cost prices the required fuel', () {
    expect(
      TripMath.tripCost(distanceKm: 100, litersPer100Km: 6, pricePerLiter: 1.5),
      closeTo(9, 0.001),
    );
  });

  test('reachable distance inverts consumption', () {
    expect(
      TripMath.reachableDistance(fuelLiters: 30, litersPer100Km: 6),
      closeTo(500, 0.001),
    );
  });

  test('consumption from a measured trip', () {
    expect(
      TripMath.consumption(distanceKm: 400, fuelLiters: 24),
      closeTo(6, 0.001),
    );
  });

  test('missing or degenerate inputs yield null', () {
    expect(
      TripMath.tripCost(
        distanceKm: null,
        litersPer100Km: 6,
        pricePerLiter: 1.5,
      ),
      isNull,
    );
    expect(
      TripMath.reachableDistance(fuelLiters: 30, litersPer100Km: 0),
      isNull,
    );
    expect(TripMath.consumption(distanceKm: 0, fuelLiters: 24), isNull);
  });
}
