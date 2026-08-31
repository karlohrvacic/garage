import '../../core/format/unit_format.dart';
import '../../domain/fuel/tank_range.dart';

/// How far the fuel in the tank still goes, in the household's distance unit,
/// or null when there is no estimate to show.
///
/// Null rather than [UnitFormat.emptyValue]: an em dash under a "Range left"
/// label is a claim that the app tried and failed, repeated on three screens
/// for every car without a tank capacity. Showing nothing at all is quieter
/// and just as true.
String? tankRangeDistance(TankRange? range, UnitFormat format) {
  final km = range?.kmLeft;
  return km == null ? null : format.formatDistance(km, decimals: 0);
}
