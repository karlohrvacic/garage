/// What a fill-up implies about consumption, checked at the moment it is
/// typed.
///
/// The app already refuses a reading below the last one and a volume larger
/// than the tank. Neither catches the commonest real mistake: a transposed
/// digit in the odometer, which reads as plausible on its own and only shows
/// up as nonsense once it meets the litres beside it. Forty litres over
/// twenty kilometres is 200 l/100 km, and nothing said so until the economy
/// figure went strange weeks later, by which time nobody remembers which
/// fill-up was wrong.
///
/// A warning, never a refusal: a jerrycan, a fill after a tow, and a
/// forgotten fill-up are all real, and the household is the one who knows.
library;

import 'energy_type.dart';

/// Litres (or kWh) per hundred kilometres implied by one fill-up, or null
/// when there is nothing to divide.
///
/// [distanceKm] of zero returns null rather than infinity: topping up twice
/// on one forecourt is ordinary, and calling it impossible would teach people
/// to ignore this.
double? impliedConsumption({
  required double? distanceKm,
  required double? quantity,
  required EnergyType energy,
}) {
  if (distanceKm == null || quantity == null || distanceKm <= 0) {
    return null;
  }
  return quantity / distanceKm * 100;
}

/// Whether a figure is outside what any road vehicle does.
///
/// Deliberately wide. A loaded van towing a trailer uphill can drink 25
/// litres per hundred, and a hypermiled diesel can manage three; both are
/// real and neither should be questioned. What is left outside the bounds is
/// arithmetic that cannot describe a journey: a mistyped odometer, a volume
/// entered as a total, or a fill-up somebody forgot to log.
bool isImplausibleConsumption(double? perHundredKm, EnergyType energy) {
  if (perHundredKm == null) {
    return false;
  }
  final (low, high) = switch (energy) {
    // kWh: a small EV does 13, a large one towing does 40.
    EnergyType.electric => (5.0, 90.0),
    EnergyType.liquid => (1.5, 60.0),
  };
  return perHundredKm < low || perHundredKm > high;
}
