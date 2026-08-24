import 'package:csv/csv.dart';

import '../../domain/entities/cost_entry.dart';
import '../../domain/entities/fuel_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/entities/odometer_entry.dart';
import '../../domain/entities/service_entry.dart';
import '../../domain/entities/trip_entry.dart';

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

/// Costs, income, trips and bare readings had no CSV form at all, while
/// `CsvEntryKind` imports all four — so a household could bring them in from
/// another app and not take them back out. Language-neutral keys and canonical
/// units here as everywhere: the category and the vignette pair store their
/// stable keys, never their translated labels.
String costEntriesToCsv(
  List<CostEntry> entries, {
  required String vehicleName,
}) {
  final rows = <List<dynamic>>[
    [
      'vehicle',
      'date',
      'category',
      'amount',
      'odometer_km',
      // The pair that decides when a vignette lapses. Blank for every other
      // category, which is what they mean there.
      'vignette_country',
      'vignette_validity',
      'notes',
    ],
    for (final entry in entries)
      [
        vehicleName,
        _date(entry.date),
        entry.category,
        entry.amount,
        entry.odometerKm ?? '',
        entry.vignetteCountry?.code ?? '',
        entry.vignetteValidity?.key ?? '',
        entry.notes ?? '',
      ],
  ];
  return Csv().encode(rows);
}

String incomeEntriesToCsv(
  List<IncomeEntry> entries, {
  required String vehicleName,
}) {
  final rows = <List<dynamic>>[
    ['vehicle', 'date', 'category', 'amount', 'odometer_km', 'notes'],
    for (final entry in entries)
      [
        vehicleName,
        _date(entry.date),
        entry.category,
        entry.amount,
        entry.odometerKm ?? '',
        entry.notes ?? '',
      ],
  ];
  return Csv().encode(rows);
}

String tripEntriesToCsv(
  List<TripEntry> entries, {
  required String vehicleName,
}) {
  final rows = <List<dynamic>>[
    [
      'vehicle',
      'date',
      'title',
      'from_place',
      'to_place',
      'distance_km',
      'purpose',
      'start_odometer_km',
      'end_odometer_km',
      'minutes',
      'notes',
    ],
    for (final entry in entries)
      [
        vehicleName,
        _date(entry.date),
        entry.title ?? '',
        entry.fromPlace ?? '',
        entry.toPlace ?? '',
        entry.distanceKm,
        // The stored key, not the label: `business` is what a logbook is for
        // and what another tool can read back.
        entry.purpose.key,
        entry.startOdometerKm ?? '',
        entry.endOdometerKm ?? '',
        entry.minutes ?? '',
        entry.notes ?? '',
      ],
  ];
  return Csv().encode(rows);
}

String odometerEntriesToCsv(
  List<OdometerEntry> entries, {
  required String vehicleName,
}) {
  final rows = <List<dynamic>>[
    ['vehicle', 'date', 'odometer_km', 'notes'],
    for (final entry in entries)
      [vehicleName, _date(entry.date), entry.odometerKm, entry.notes ?? ''],
  ];
  return Csv().encode(rows);
}

String _date(DateTime value) => value.toIso8601String().split('T').first;
