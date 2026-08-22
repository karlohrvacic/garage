import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/import/fuelio_backup.dart';

FuelioFillUp fill({String? station}) => FuelioFillUp(
  date: DateTime.utc(2026, 8, 12),
  odometerKm: 48029,
  volumeL: 37.7,
  fullTank: true,
  missedFill: false,
  station: station,
);

FuelioBackup backupOf(List<FuelioFillUp> fills) => FuelioBackup(
  fillUps: fills,
  costs: const [],
  services: const [],
  reminders: const [],
);

void main() {
  // Fuelio's export has a City column and a StationID column, and a real
  // export has both empty on every row: the app it came from does not record
  // where the fuel was bought in any form this file carries. Every imported
  // fill-up therefore arrives with no station, which is worth offering to fix
  // once rather than leaving fifty rows to be edited by hand.
  group('whether a backup names any station', () {
    test('a file with no station anywhere says so', () {
      expect(backupOf([fill(), fill()]).hasAnyStation, isFalse);
    });

    test('one named station is enough to leave it alone', () {
      expect(backupOf([fill(), fill(station: 'INA')]).hasAnyStation, isTrue);
    });

    test('a blank string is not a station', () {
      expect(
        backupOf([fill(station: ''), fill(station: '   ')]).hasAnyStation,
        isFalse,
      );
    });

    test('a file with no fill-ups at all has nothing to offer', () {
      // Nothing to apply a station to, so the prompt would be asking about
      // rows that do not exist.
      expect(backupOf(const []).hasAnyStation, isFalse);
      expect(backupOf(const []).fillUps, isEmpty);
    });
  });

  test('the real export in docs/wishlist carries no station', () async {
    // The file that prompted this. If a future Fuelio version starts filling
    // City in, this fails and the prompt should stop being offered.
    final backup = parseFuelioBackup(await _wishlistExport());

    expect(backup.fillUps, isNotEmpty);
    expect(backup.hasAnyStation, isFalse);
  });
}

Future<String> _wishlistExport() async {
  const path = 'docs/wishlist/Fuelio Renault Clio-1-2026-08-15_23-21.csv';
  return await File(path).readAsString();
}
