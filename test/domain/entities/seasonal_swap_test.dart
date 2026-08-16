import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/tyre_set.dart';

TyreSet set({
  String id = 't1',
  TyreSeason season = TyreSeason.winter,
  bool fitted = false,
  DateTime? retiredAt,
}) {
  return TyreSet(
    id: id,
    vehicleId: 'v1',
    name: season.key,
    season: season,
    fitted: fitted,
    retiredAt: retiredAt,
    createdBy: 'u1',
  );
}

void main() {
  group('whether a car swaps tyres by season', () {
    // A seasonal swap reminder is a statement about how the car is shod. On
    // all-season tyres there is no swap to do, and the reminder is noise that
    // recurs twice a year forever.
    test('a car on all-season tyres does not', () {
      expect(
        TyreSeasons.swapsSeasonally([
          set(season: TyreSeason.allSeason, fitted: true),
        ]),
        isFalse,
      );
    });

    test('a car with a winter and a summer set does', () {
      final sets = [
        set(id: 'w', season: TyreSeason.winter, fitted: true),
        set(id: 's', season: TyreSeason.summer),
      ];

      expect(TyreSeasons.swapsSeasonally(sets), isTrue);
    });

    test(
      'a car with one seasonal set does, since the other may be untracked',
      () {
        expect(
          TyreSeasons.swapsSeasonally([set(season: TyreSeason.winter)]),
          isTrue,
        );
      },
    );

    test('a car with no tyre sets recorded is assumed to, as before', () {
      // Tyre tracking is optional. Absence of data is not evidence that the
      // household runs all-season tyres, so nothing is suppressed.
      expect(TyreSeasons.swapsSeasonally(const []), isTrue);
    });

    test('a retired seasonal set does not keep the swap alive', () {
      final sets = [
        set(id: 'a', season: TyreSeason.allSeason, fitted: true),
        set(
          id: 'w',
          season: TyreSeason.winter,
          retiredAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      expect(TyreSeasons.swapsSeasonally(sets), isFalse);
    });
  });
}
