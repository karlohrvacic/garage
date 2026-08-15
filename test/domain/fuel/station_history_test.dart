import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/station_history.dart';

FuelEntry fill({required String id, required DateTime date, String? station}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    odometerKm: 1000,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
    station: station,
    createdBy: 'u1',
  );
}

void main() {
  group('rank', () {
    test('puts the most-used station first', () {
      final ranked = StationHistory.rank([
        fill(id: '1', date: DateTime.utc(2026, 1, 1), station: 'Shell'),
        fill(id: '2', date: DateTime.utc(2026, 2, 1), station: 'INA'),
        fill(id: '3', date: DateTime.utc(2026, 3, 1), station: 'INA'),
      ]);

      expect(ranked, ['INA', 'Shell']);
    });

    test('breaks a tie on how recently the station was used', () {
      final ranked = StationHistory.rank([
        fill(id: '1', date: DateTime.utc(2026, 1, 1), station: 'Shell'),
        fill(id: '2', date: DateTime.utc(2026, 5, 1), station: 'INA'),
      ]);

      expect(ranked, ['INA', 'Shell']);
    });

    test('folds case so one station is not offered twice', () {
      final ranked = StationHistory.rank([
        fill(id: '1', date: DateTime.utc(2026, 1, 1), station: 'ina'),
        fill(id: '2', date: DateTime.utc(2026, 2, 1), station: 'INA'),
      ]);

      expect(ranked, ['INA']);
    });

    test('trims surrounding whitespace before comparing', () {
      final ranked = StationHistory.rank([
        fill(id: '1', date: DateTime.utc(2026, 1, 1), station: ' INA '),
        fill(id: '2', date: DateTime.utc(2026, 2, 1), station: 'INA'),
      ]);

      expect(ranked, ['INA']);
    });

    test('ignores entries with no station', () {
      final ranked = StationHistory.rank([
        fill(id: '1', date: DateTime.utc(2026, 1, 1)),
        fill(id: '2', date: DateTime.utc(2026, 2, 1), station: '   '),
        fill(id: '3', date: DateTime.utc(2026, 3, 1), station: 'INA'),
      ]);

      expect(ranked, ['INA']);
    });

    test('is empty for an empty log', () {
      expect(StationHistory.rank(const []), isEmpty);
    });
  });

  group('matching', () {
    test('offers everything for an empty query', () {
      expect(StationHistory.matching(['INA', 'Shell'], '  '), ['INA', 'Shell']);
    });

    test('matches anywhere in the name, ignoring case', () {
      expect(StationHistory.matching(['INA', 'Petrolina', 'Shell'], 'ina'), [
        'INA',
        'Petrolina',
      ]);
    });
  });
}
