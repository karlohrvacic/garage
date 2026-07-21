import 'package:csv/csv.dart';

import '../../domain/entities/fuel_entry.dart';
import '../../domain/entities/service_entry.dart';

/// CSV export, in canonical units with language-neutral keys.
///
/// This doubles as the GDPR data-portability mechanism, which is why it is a
/// plain readable format with no app-specific encoding: the user must be able
/// to open it in a spreadsheet or import it elsewhere without this app.
String fuelEntriesToCsv(
  List<FuelEntry> entries, {
  required String vehicleName,
}) {
  final rows = <List<dynamic>>[
    [
      'vehicle',
      'date',
      'odometer_km',
      'volume_l',
      'price_per_l',
      'total',
      'full_tank',
      'missed_fill',
      'station',
      'notes',
    ],
    for (final entry in entries)
      [
        vehicleName,
        _date(entry.date),
        entry.odometerKm,
        entry.volumeL,
        entry.pricePerL ?? '',
        entry.total ?? '',
        entry.fullTank,
        entry.missedFill,
        entry.station ?? '',
        entry.notes ?? '',
      ],
  ];
  return Csv().encode(rows);
}

String serviceEntriesToCsv(
  List<ServiceEntry> entries, {
  required String vehicleName,
}) {
  final rows = <List<dynamic>>[
    [
      'vehicle',
      'date',
      'odometer_km',
      'service_types',
      'cost',
      'shop',
      'notes',
    ],
    for (final entry in entries)
      [
        vehicleName,
        _date(entry.date),
        entry.odometerKm,
        // Semicolons, so the list survives a comma-separated file.
        entry.serviceTypeKeys.join(';'),
        entry.cost ?? '',
        entry.shop ?? '',
        entry.notes ?? '',
      ],
  ];
  return Csv().encode(rows);
}

String _date(DateTime value) => value.toIso8601String().split('T').first;
