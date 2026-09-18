import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/domain/stations/station_brands.dart';

FuelStation forecourt(
  int id,
  String name, {
  String? brand,
  String? chainBrand,
}) => FuelStation(
  id: id,
  name: name,
  brand: brand,
  address: 'Ilica 1',
  place: 'Zagreb',
  lat: 45.8,
  lng: 15.9,
  prices: const [],
  chainBrand: chainBrand,
);

void main() {
  group('what an older fill-up is logged under today', () {
    // A fill-up saved before decision 161 kept the feed's own name, "PM
    // POREČ, ŽBANDAJ"; one saved since 170 keeps the brand. The same
    // forecourt was two stations in the statistics.
    final stations = [
      forecourt(
        1,
        'PM POREČ, ŽBANDAJ',
        brand: 'PETROL d.o.o.',
        chainBrand: 'Petrol',
      ),
      forecourt(
        2,
        'Krapina - Frana Galovića',
        brand: 'INA – Industrija nafte d.d.',
        chainBrand: 'INA',
      ),
      forecourt(3, 'Santini', brand: 'Santini d.o.o.'),
    ];
    final brands = StationBrands(stations);

    test('the feed name of a chain forecourt is its brand', () {
      expect(brands.of('PM POREČ, ŽBANDAJ'), 'Petrol');
      expect(brands.of('Krapina - Frana Galovića'), 'INA');
    });

    test('and so is the name the sign gave it', () {
      // What decision 161 wrote: the forecourt word replaced by the brand.
      expect(brands.of('Petrol POREČ, ŽBANDAJ'), 'Petrol');
    });

    test('in any case, and with stray spaces', () {
      expect(brands.of('  pm poreč, žbandaj '), 'Petrol');
    });

    test('an independent keeps its own name', () {
      expect(brands.of('Santini'), 'Santini');
    });

    test('a name the feed does not know is left as it was written', () {
      expect(brands.of('The garage by the lake'), 'The garage by the lake');
      expect(brands.of('Petrol'), 'Petrol');
    });

    test('a name two brands share says nothing', () {
      final shared = StationBrands([
        forecourt(1, 'BP ZAGREB', brand: 'Tifon d.o.o.', chainBrand: 'Tifon'),
        forecourt(2, 'BP ZAGREB', brand: 'Lukoil', chainBrand: 'LUKOIL'),
      ]);

      expect(shared.of('BP ZAGREB'), 'BP ZAGREB');
    });

    test('without the feed, every name stays', () {
      expect(StationBrands.none.of('PM POREČ, ŽBANDAJ'), 'PM POREČ, ŽBANDAJ');
    });
  });
}
