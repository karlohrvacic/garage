import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/vehicles/widgets/economy_gauge.dart';

void main() {
  test('the best economy fills the gauge', () {
    expect(gaugeFraction(economy: 4, best: 4, worst: 12), 1.0);
  });

  test('the worst economy empties it', () {
    expect(gaugeFraction(economy: 12, best: 4, worst: 12), 0.0);
  });

  test('a mid figure sits halfway', () {
    expect(gaugeFraction(economy: 8, best: 4, worst: 12), closeTo(0.5, 0.0001));
  });

  test('a figure better than the range clamps to full', () {
    expect(gaugeFraction(economy: 2, best: 4, worst: 12), 1.0);
  });

  test('a figure worse than the range clamps to empty', () {
    expect(gaugeFraction(economy: 20, best: 4, worst: 12), 0.0);
  });

  test('a null economy reads as empty rather than throwing', () {
    expect(gaugeFraction(economy: null, best: 4, worst: 12), 0.0);
  });

  test('a degenerate range does not divide by zero', () {
    expect(gaugeFraction(economy: 8, best: 8, worst: 8), 0.0);
  });
}
