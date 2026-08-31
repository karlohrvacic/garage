import 'fuel_economy.dart';

/// The fewest other tanks worth averaging against.
///
/// The same three `StationEconomy.defaultMinimumTanks` settled on, for the same
/// stated reason: below it, a single unusual tank simply *is* the average.
const int minimumOtherTanks = 3;

/// Below this, the difference is how the pump cut off, not how the car drove.
/// `StationEconomy.meaningfulDifference` uses the same five percent.
const double economyNoiseFloor = 0.05;

/// How far this tank ran from the car's usual, as a fraction: 0.25 means a
/// quarter thirstier than the others, -0.10 a tenth better.
///
/// The row already colours this figure green or red against the car's best and
/// worst ever. That says *where* the tank sits; it cannot say by how much, and
/// a colour with no number behind it is a verdict without evidence. This is
/// the evidence — not a second warning.
///
/// Null when there is nothing honest to compare against.
double? deviationFor(String entryId, List<EconomyPoint> points) {
  EconomyPoint? subject;
  final others = <EconomyPoint>[];
  for (final point in points) {
    if (point.entryId == entryId && subject == null) {
      subject = point;
    } else {
      others.add(point);
    }
  }
  if (subject == null || others.length < minimumOtherTanks) {
    return null;
  }

  // Against the others rather than against everything: a tank inside its own
  // baseline pulls that baseline towards itself and reports a smaller
  // deviation than actually happened.
  final baseline = FuelEconomy.average(others);
  if (baseline == null || baseline <= 0) {
    return null;
  }
  return (subject.litersPer100Km - baseline) / baseline;
}

/// Whether a deviation is large enough to put on screen.
bool worthMentioning(double? deviation) {
  return deviation != null && deviation.abs() >= economyNoiseFloor * 2;
}
