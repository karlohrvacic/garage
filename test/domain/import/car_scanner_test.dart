import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/import/car_scanner.dart';

/// Shaped exactly like a real export: header in quotes, semicolons, one row
/// per sample per channel, and a running maximum rather than a total on the
/// last line.
const _record = '''
"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";
"85095.1";"Speed (GPS)";"0";"km/h";"45.79";"15.72";
"85095.4";"Distance travelled";"0";"km";"45.79";"15.72";
"85095.4";"Distance travelled (total)";"45.26";"km";"45.79";"15.72";
"86000.0";"Distance travelled";"12.4";"km";"45.80";"15.73";
"86000.0";"Fuel used";"0.9";"L";"45.80";"15.73";
"86000.0";"Average fuel consumption";"898.4";"L/100km";"45.80";"15.73";
"87039.0";"Distance travelled";"32.37";"km";"45.81";"15.74";
"87039.0";"Distance travelled (total)";"77.62";"km";"45.81";"15.74";
"87039.0";"Fuel used";"1.84";"L";"45.81";"15.74";
"87039.0";"Fuel used price";"2.57";"€";"45.81";"15.74";
''';

CarScannerDrive? read(String csv, {String name = '2026-01-27 23-38-14.csv'}) {
  final reading = CarScannerReading();
  for (final line in csv.trim().split('\n')) {
    reading.addLine(line.trim());
  }
  return reading.drive(carScannerDateFromName(name));
}

void main() {
  group('one recording is one drive', () {
    test('the distance is the drive, not the running total', () {
      // `Distance travelled (total)` counts across drives from wherever the
      // app was installed. Reading it as this drive would report 77 km for a
      // 32 km journey, and as an odometer it would be a fabricated reading.
      expect(read(_record)!.distanceKm, 32.37);
    });

    test('fuel and what it cost come across', () {
      expect(read(_record)!.litresUsed, 1.84);
      expect(read(_record)!.amountPaid, 2.57);
    });

    test('consumption is worked out, not read from the file', () {
      // The file's own average spikes to 898 L/100km whenever the car idles.
      final drive = read(_record)!;

      expect(drive.litresPerHundredKm, closeTo(5.68, 0.01));
    });

    test('minutes are the span of the samples, rounded', () {
      // 85095.1 to 87039.0 is 32.4 minutes.
      expect(read(_record)!.minutes, 32);
    });

    test('the day comes from the file name, not the clock', () {
      expect(read(_record)!.startedAt, DateTime(2026, 1, 27, 23, 38, 14));
    });

    test('a name in no recognised shape yields no date', () {
      expect(carScannerDateFromName('drive.csv'), isNull);
    });

    test('and the drive is undated rather than dated today', () {
      // Today's date would be a guess wearing the clothes of a fact, and a
      // trip log is the last place for one. The screen asks instead.
      expect(read(_record, name: 'drive.csv')!.startedAt, isNull);
    });
  });

  group('a file the phone wrote in its own locale', () {
    // Car Scanner follows the device locale, and the export is semicolon-
    // delimited precisely because the comma can be the decimal separator.
    // Read strictly, such a file has no parseable rows at all: it is not
    // recognised as a recording and falls through to the column-mapping
    // screen, which tells the user their recording is an unmappable table.
    const comma = '''
"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";
"85095,1";"Distance travelled";"0";"km";"45,79";"15,72";
"87039,0";"Distance travelled";"32,37";"km";"45,81";"15,74";
"87039,0";"Fuel used";"1,84";"L";"45,81";"15,74";
''';

    test('is read, not rejected', () {
      final drive = read(comma)!;

      expect(drive.distanceKm, 32.37);
      expect(drive.litresUsed, 1.84);
      expect(drive.minutes, 32);
    });

    test('and a file in the machine convention still reads the same', () {
      // The plain parse runs first, so nothing about the common case changes.
      expect(read(_record)!.distanceKm, 32.37);
    });

    test('grouped thousands go to the right number either way', () {
      // The later separator is the decimal one, which holds in both
      // conventions — the only rule that reads "1.234,56" and "1,234.56"
      // as the same distance.
      expect(
        read('''
"SECONDS";"PID";"VALUE";"UNITS"
"0";"Distance travelled";"1.234,56";"km"
''')!.distanceKm,
        1234.56,
      );
      expect(
        read('''
"SECONDS";"PID";"VALUE";"UNITS"
"0";"Distance travelled";"1,234.56";"km"
''')!.distanceKm,
        1234.56,
      );
    });
  });

  group('what is not a drive', () {
    test('a file with no Car Scanner header is not recognised', () {
      final reading = CarScannerReading()
        ..addLine('date,odometer,litres,total')
        ..addLine('2026-01-27,180000,42.1,63.20');

      expect(reading.recognised, isFalse);
      expect(reading.drive(DateTime(2026)), isNull);
    });

    test('a header with no rows under it is not a drive either', () {
      final reading = CarScannerReading()
        ..addLine('"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";');

      expect(reading.drive(DateTime(2026)), isNull);
    });

    test('a scanner left running in a parked car says so', () {
      // 103 minutes and 0.82 km is a real file from a real phone: the car
      // never moved. Importing it as a journey would put a 0.5 km/h trip in a
      // logbook somebody might one day hand to a tax inspector.
      final parked = read('''
"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";
"53106.0";"Distance travelled";"0";"km";"45.79";"15.72";
"59290.0";"Distance travelled";"0.42";"km";"45.79";"15.72";
''');

      expect(parked!.wentNowhere, isTrue);
      expect(read(_record)!.wentNowhere, isFalse);
    });

    test('a drive with no distance channel still reports its minutes', () {
      // GPS-only recordings exist: no OBD connection, so no distance. The
      // trip is still real; the app has to ask for the distance.
      final gpsOnly = read('''
"SECONDS";"PID";"VALUE";"UNITS";"LATITUDE";"LONGTITUDE";
"53219.7";"Speed (GPS)";"0";"km/h";"45.79";"15.72";
"53819.7";"Speed (GPS)";"41";"km/h";"45.80";"15.73";
''');

      expect(gpsOnly!.distanceKm, isNull);
      expect(gpsOnly.minutes, 10);
    });
  });
}
