import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/domain/stats/station_economy.dart';

EconomyPoint point(double litersPer100Km, {String? station, double km = 500}) {
  return EconomyPoint(
    entryId: 'e',
    date: DateTime.utc(2026, 1, 1),
    odometerKm: 1000,
    litersPer100Km: litersPer100Km,
    distanceKm: km,
    volumeL: litersPer100Km * km / 100,
    station: station,
  );
}

List<EconomyPoint> many(int count, double economy, String station) => [
  for (var i = 0; i < count; i++) point(economy, station: station),
];

void main() {
  group('comparing economy between stations', () {
    test('reports a station once it has enough tanks to mean anything', () {
      final result = StationEconomy.compare([
        ...many(4, 6.0, 'INA'),
        ...many(4, 6.5, 'Shell'),
      ]);

      expect(result.map((s) => s.station), ['INA', 'Shell']);
      expect(result.first.litersPer100Km, closeTo(6.0, 0.001));
    });

    test('best first, because that is the question being asked', () {
      final result = StationEconomy.compare([
        ...many(4, 7.0, 'Shell'),
        ...many(4, 6.0, 'INA'),
      ]);

      expect(result.first.station, 'INA');
    });

    test('a station with too few tanks is left out, not shown as thin', () {
      // Two tanks at one station is not evidence about that station; showing
      // it with a caveat invites exactly the comparison the caveat forbids.
      final result = StationEconomy.compare([
        ...many(4, 6.0, 'INA'),
        ...many(2, 5.0, 'Lukoil'),
      ]);

      expect(result.map((s) => s.station), ['INA']);
    });

    test('unattributable tanks are ignored entirely', () {
      final result = StationEconomy.compare([
        ...many(4, 6.0, 'INA'),
        ...many(9, 4.0, ''),
        for (var i = 0; i < 9; i++) point(4.0),
      ]);

      expect(result.map((s) => s.station), ['INA']);
    });

    test('the average is distance-weighted, not a mean of the figures', () {
      // A 100 km tank must not count as much as a 900 km one.
      final result = StationEconomy.compare([
        point(10, station: 'INA', km: 100),
        point(5, station: 'INA', km: 900),
        point(5, station: 'INA', km: 900),
      ], minimumTanks: 3);

      expect(result.single.litersPer100Km, lessThan(5.6));
    });

    test('nothing to compare when only one station qualifies', () {
      // "You get better mileage at INA" needs something to be better *than*.
      final result = StationEconomy.compare([...many(9, 6.0, 'INA')]);

      expect(result, hasLength(1));
      expect(StationEconomy.worthShowing(result), isFalse);
    });

    test('two qualifying stations are worth showing', () {
      final result = StationEconomy.compare([
        ...many(4, 6.0, 'INA'),
        ...many(4, 6.5, 'Shell'),
      ]);

      expect(StationEconomy.worthShowing(result), isTrue);
    });

    test('a difference under the noise floor is not worth showing', () {
      // Driving, weather and season swamp fuel brand. A 1% gap between two
      // stations is not a finding, and dressing it as one is the whole way
      // this feature could mislead.
      final result = StationEconomy.compare([
        ...many(4, 6.00, 'INA'),
        ...many(4, 6.03, 'Shell'),
      ]);

      expect(StationEconomy.worthShowing(result), isFalse);
    });

    test('each station carries how many tanks stand behind it', () {
      final result = StationEconomy.compare([
        ...many(5, 6.0, 'INA'),
        ...many(4, 6.5, 'Shell'),
      ]);

      expect(result.first.tanks, 5);
      expect(result.last.tanks, 4);
    });
  });
}
