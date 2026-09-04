import 'package:csv/csv.dart';

import '../../domain/entities/cost_entry.dart';
import '../../domain/entities/fuel_entry.dart';
import '../../domain/entities/income_entry.dart';
import '../../domain/entities/odometer_entry.dart';
import '../../domain/entities/service_entry.dart';
import '../../domain/entities/trip_entry.dart';
import '../../domain/entities/tyre_set.dart';
import '../../domain/entities/vehicle.dart';

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
      'cheapest_nearby_price',
      'cheapest_nearby_km',
      'cheapest_nearby_station',
      'prices_seen_on',
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
        entry.priceContext?.pricePerUnit ?? '',
        entry.priceContext?.distanceKm ?? '',
        entry.priceContext?.station ?? '',
        switch (entry.priceContext?.seenOn) {
          null => '',
          final seen => _date(seen),
        },
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

/// The cars themselves, which no section of the old export carried: a
/// household that exported before leaving took its history and left behind
/// what the history was about.
String vehiclesToCsv(List<Vehicle> vehicles) {
  final rows = <List<dynamic>>[
    [
      'name',
      'make',
      'model',
      'trim',
      'year',
      'plate',
      'vin',
      'kind',
      'fuel_type',
      'secondary_fuel_type',
      'transmission',
      'timing_drive',
      'final_drive',
      'tank_capacity_l',
      'purchase_price',
      'baseline_odometer_km',
      'baseline_date',
      'archived',
    ],
    for (final vehicle in vehicles)
      [
        vehicle.nickname,
        vehicle.make ?? '',
        vehicle.model ?? '',
        vehicle.trim ?? '',
        vehicle.year ?? '',
        vehicle.plate ?? '',
        vehicle.vin ?? '',
        vehicle.kind,
        vehicle.fuelTypeKey,
        vehicle.secondaryFuelTypeKey ?? '',
        vehicle.transmission ?? '',
        vehicle.timingDrive ?? '',
        vehicle.finalDrive ?? '',
        vehicle.tankCapacityL ?? '',
        vehicle.purchasePrice ?? '',
        vehicle.baselineOdometerKm,
        _date(vehicle.baselineDate),
        vehicle.archived,
      ],
  ];
  return Csv().encode(rows);
}

/// Tyre sets with their tread readings, one row per reading and one row for a
/// set nobody has measured. Left out of the export entirely until now, so a
/// household exporting before it left lost the one history that cannot be
/// reconstructed afterwards.
String tyreSetsToCsv(List<TyreSet> sets, {required String vehicleName}) {
  final rows = <List<dynamic>>[
    [
      'vehicle',
      'set',
      'season',
      'size',
      'storage_location',
      'fitted',
      'fitted_at',
      'retired_at',
      'manufactured_on',
      'reading_date',
      'odometer_km',
      'front_left_mm',
      'front_right_mm',
      'rear_left_mm',
      'rear_right_mm',
    ],
    for (final set in sets)
      if (set.readings.isEmpty)
        [
          vehicleName,
          set.name,
          set.season.key,
          set.size ?? '',
          set.storageLocation ?? '',
          set.fitted,
          switch (set.fittedAt) {
            null => '',
            final at => _date(at),
          },
          switch (set.retiredAt) {
            null => '',
            final at => _date(at),
          },
          switch (set.manufacturedOn) {
            null => '',
            final on => _date(on),
          },
          '',
          '',
          '',
          '',
          '',
          '',
        ]
      else
        for (final reading in set.readings)
          [
            vehicleName,
            set.name,
            set.season.key,
            set.size ?? '',
            set.storageLocation ?? '',
            set.fitted,
            switch (set.fittedAt) {
              null => '',
              final at => _date(at),
            },
            switch (set.retiredAt) {
              null => '',
              final at => _date(at),
            },
            switch (set.manufacturedOn) {
              null => '',
              final on => _date(on),
            },
            _date(reading.date),
            reading.odometerKm ?? '',
            reading.frontLeftMm ?? '',
            reading.frontRightMm ?? '',
            reading.rearLeftMm ?? '',
            reading.rearRightMm ?? '',
          ],
  ];
  return Csv().encode(rows);
}

String _date(DateTime value) => value.toIso8601String().split('T').first;
