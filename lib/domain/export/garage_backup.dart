import 'dart:convert';

import '../entities/cost_entry.dart';
import '../entities/fuel_entry.dart';
import '../entities/income_entry.dart';
import '../entities/odometer_entry.dart';
import '../entities/reminder_rule.dart';
import '../entities/service_entry.dart';
import '../entities/trip_entry.dart';
import '../entities/tyre_set.dart';
import '../entities/vehicle.dart';

/// Thrown when a file is not a backup this build can read.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason);

  final String reason;

  @override
  String toString() => 'BackupFormatException: $reason';
}

/// One vehicle and everything logged against it.
class VehicleBackup {
  const VehicleBackup({
    required this.vehicle,
    this.fuel = const [],
    this.services = const [],
    this.costs = const [],
    this.readings = const [],
    this.trips = const [],
    this.income = const [],
    this.rules = const [],
    this.tyres = const [],
  });

  final Vehicle vehicle;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<OdometerEntry> readings;
  final List<TripEntry> trips;
  final List<IncomeEntry> income;

  /// The reminder rules set up for this vehicle. Carried because losing them
  /// is the one loss a restore cannot show: the log comes back, the
  /// notifications quietly never do.
  final List<ReminderRule> rules;

  /// Tyre sets with their tread history. The one part of a garage nobody can
  /// measure again after the fact: a tread reading from two winters ago is
  /// gone the moment it is lost.
  final List<TyreSet> tyres;
}

class RestoredBackup {
  const RestoredBackup({
    required this.version,
    required this.householdName,
    required this.vehicles,
  });

  final int version;
  final String householdName;
  final List<VehicleBackup> vehicles;
}

/// A whole garage as one JSON file.
///
/// The CSV export is the portability format — readable in a spreadsheet, no
/// app-specific encoding, which is what data portability actually means. This
/// is the other thing: a file that comes *back*. A CSV loses the shape (which
/// service types a visit covered, whether a tank was full) and cannot restore
/// what it exported; this can.
///
/// Nothing here is compressed or obfuscated. A backup somebody cannot read is
/// a backup they cannot trust, and this one is JSON on purpose.
abstract final class GarageBackup {
  /// Bumped whenever the shape changes in a way an older build would read
  /// wrongly. A build refuses a version it does not know rather than importing
  /// half of it.
  static const currentVersion = 1;

  static String encode(
    List<VehicleBackup> vehicles, {
    required String householdName,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'garage-backup',
      'version': currentVersion,
      'household': householdName,
      'vehicles': [
        for (final entry in vehicles)
          {
            'vehicle': _vehicle(entry.vehicle),
            'fuel': [for (final e in entry.fuel) _fuel(e)],
            'services': [for (final e in entry.services) _service(e)],
            'costs': [for (final e in entry.costs) _cost(e)],
            'readings': [for (final e in entry.readings) _reading(e)],
            'trips': [for (final e in entry.trips) _trip(e)],
            'income': [for (final e in entry.income) _income(e)],
            'rules': [for (final e in entry.rules) _rule(e)],
            'tyres': [for (final e in entry.tyres) _tyres(e)],
          },
      ],
    });
  }

  static RestoredBackup decode(String text) {
    final Object? parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      throw const BackupFormatException('not JSON');
    }
    if (parsed is! Map<String, dynamic> ||
        parsed['format'] != 'garage-backup') {
      throw const BackupFormatException('not a Garage backup');
    }
    final version = parsed['version'];
    if (version is! int || version > currentVersion) {
      throw BackupFormatException('unsupported version $version');
    }

    final vehicles = parsed['vehicles'];
    return RestoredBackup(
      version: version,
      householdName: parsed['household'] as String? ?? '',
      vehicles: [
        if (vehicles is List)
          for (final raw in vehicles)
            if (raw is Map<String, dynamic>) _vehicleBackup(raw),
      ],
    );
  }

  static VehicleBackup _vehicleBackup(Map<String, dynamic> raw) {
    final vehicle = _readVehicle(raw['vehicle'] as Map<String, dynamic>);
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) {
      final value = raw[key];
      return [
        if (value is List)
          for (final item in value)
            if (item is Map<String, dynamic>) read(item),
      ];
    }

    return VehicleBackup(
      vehicle: vehicle,
      fuel: list('fuel', (e) => _readFuel(e, vehicle.id)),
      services: list('services', (e) => _readService(e, vehicle.id)),
      costs: list('costs', (e) => _readCost(e, vehicle.id)),
      readings: list('readings', (e) => _readReading(e, vehicle.id)),
      trips: list('trips', (e) => _readTrip(e, vehicle.id)),
      income: list('income', (e) => _readIncome(e, vehicle.id)),
      // Absent in files written before reminders were carried, which read as
      // a vehicle with none rather than as a broken backup.
      rules: list('rules', (e) => _readRule(e, vehicle.id)),
      tyres: list('tyres', (e) => _readTyres(e, vehicle.id)),
    );
  }

  /// Dates are written as the calendar day, never as an instant: a backup
  /// taken in Zagreb and restored anywhere else has to land on the same day,
  /// which is what the whole log is ordered by.
  static String _day(DateTime date) =>
      date.toUtc().toIso8601String().split('T').first;

  static DateTime _readDay(Object? value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) {
      throw BackupFormatException('bad date: $value');
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static double? _readDouble(Object? value) =>
      value is num ? value.toDouble() : null;

  static int? _readInt(Object? value) => value is num ? value.round() : null;

  static Map<String, dynamic> _vehicle(Vehicle v) => {
    'id': v.id,
    'nickname': v.nickname,
    'fuel_type_key': v.fuelTypeKey,
    'secondary_fuel_type_key': v.secondaryFuelTypeKey,
    'baseline_odometer_km': v.baselineOdometerKm,
    'baseline_date': _day(v.baselineDate),
    'make': v.make,
    'model': v.model,
    'year': v.year,
    'trim': v.trim,
    'vin': v.vin,
    'plate': v.plate,
    'tank_capacity_l': v.tankCapacityL,
    'archived': v.archived,
  };

  static Vehicle _readVehicle(Map<String, dynamic> raw) => Vehicle(
    id: raw['id'] as String? ?? '',
    householdId: '',
    nickname: raw['nickname'] as String? ?? '',
    fuelTypeKey: raw['fuel_type_key'] as String? ?? 'fuel_petrol',
    secondaryFuelTypeKey: raw['secondary_fuel_type_key'] as String?,
    baselineOdometerKm: _readInt(raw['baseline_odometer_km']) ?? 0,
    baselineDate: _readDay(raw['baseline_date']),
    make: raw['make'] as String?,
    model: raw['model'] as String?,
    year: _readInt(raw['year']),
    trim: raw['trim'] as String?,
    vin: raw['vin'] as String?,
    plate: raw['plate'] as String?,
    tankCapacityL: _readDouble(raw['tank_capacity_l']),
    archived: raw['archived'] as bool? ?? false,
  );

  static Map<String, dynamic> _fuel(FuelEntry e) => {
    'date': _day(e.date),
    'odometer_km': e.odometerKm,
    'volume_l': e.volumeL,
    'price_per_l': e.pricePerL,
    'total': e.total,
    'full_tank': e.fullTank,
    'missed_fill': e.missedFill,
    'fuel_type_key': e.fuelTypeKey,
    'station': e.station,
    'notes': e.notes,
  };

  static FuelEntry _readFuel(Map<String, dynamic> raw, String vehicleId) =>
      FuelEntry(
        id: '',
        vehicleId: vehicleId,
        date: _readDay(raw['date']),
        odometerKm: _readInt(raw['odometer_km']) ?? 0,
        volumeL: _readDouble(raw['volume_l']) ?? 0,
        pricePerL: _readDouble(raw['price_per_l']),
        total: _readDouble(raw['total']),
        fullTank: raw['full_tank'] as bool? ?? true,
        missedFill: raw['missed_fill'] as bool? ?? false,
        fuelTypeKey: raw['fuel_type_key'] as String?,
        station: raw['station'] as String?,
        notes: raw['notes'] as String?,
        createdBy: '',
      );

  static Map<String, dynamic> _service(ServiceEntry e) => {
    'date': _day(e.date),
    'odometer_km': e.odometerKm,
    'service_type_keys': e.serviceTypeKeys,
    'cost': e.cost,
    'parts_cost': e.partsCost,
    'labor_cost': e.laborCost,
    'shop': e.shop,
    'notes': e.notes,
  };

  static ServiceEntry _readService(
    Map<String, dynamic> raw,
    String vehicleId,
  ) => ServiceEntry(
    id: '',
    vehicleId: vehicleId,
    date: _readDay(raw['date']),
    odometerKm: _readInt(raw['odometer_km']) ?? 0,
    serviceTypeKeys: [
      if (raw['service_type_keys'] case final List keys)
        for (final key in keys) '$key',
    ],
    cost: _readDouble(raw['cost']),
    partsCost: _readDouble(raw['parts_cost']),
    laborCost: _readDouble(raw['labor_cost']),
    shop: raw['shop'] as String?,
    notes: raw['notes'] as String?,
    createdBy: '',
  );

  static Map<String, dynamic> _cost(CostEntry e) => {
    'date': _day(e.date),
    'category': e.category,
    'amount': e.amount,
    'odometer_km': e.odometerKm,
    'notes': e.notes,
  };

  static CostEntry _readCost(Map<String, dynamic> raw, String vehicleId) =>
      CostEntry(
        id: '',
        vehicleId: vehicleId,
        date: _readDay(raw['date']),
        category: raw['category'] as String? ?? CostCategories.other,
        amount: _readDouble(raw['amount']) ?? 0,
        odometerKm: _readInt(raw['odometer_km']),
        notes: raw['notes'] as String?,
        createdBy: '',
      );

  static Map<String, dynamic> _reading(OdometerEntry e) => {
    'date': _day(e.date),
    'odometer_km': e.odometerKm,
    'notes': e.notes,
  };

  static OdometerEntry _readReading(
    Map<String, dynamic> raw,
    String vehicleId,
  ) => OdometerEntry(
    id: '',
    vehicleId: vehicleId,
    date: _readDay(raw['date']),
    odometerKm: _readInt(raw['odometer_km']) ?? 0,
    notes: raw['notes'] as String?,
    createdBy: '',
  );

  static Map<String, dynamic> _trip(TripEntry e) => {
    'date': _day(e.date),
    'distance_km': e.distanceKm,
    'purpose': e.purpose.key,
    'title': e.title,
    'from_place': e.fromPlace,
    'to_place': e.toPlace,
    'start_odometer_km': e.startOdometerKm,
    'end_odometer_km': e.endOdometerKm,
    'minutes': e.minutes,
    'notes': e.notes,
  };

  static TripEntry _readTrip(Map<String, dynamic> raw, String vehicleId) =>
      TripEntry(
        id: '',
        vehicleId: vehicleId,
        date: _readDay(raw['date']),
        distanceKm: _readDouble(raw['distance_km']) ?? 0,
        purpose: TripPurpose.fromKey(raw['purpose'] as String? ?? 'private'),
        title: raw['title'] as String?,
        fromPlace: raw['from_place'] as String?,
        toPlace: raw['to_place'] as String?,
        startOdometerKm: _readInt(raw['start_odometer_km']),
        endOdometerKm: _readInt(raw['end_odometer_km']),
        minutes: _readInt(raw['minutes']),
        notes: raw['notes'] as String?,
        createdBy: '',
      );

  static Map<String, dynamic> _income(IncomeEntry e) => {
    'date': _day(e.date),
    'category': e.category,
    'amount': e.amount,
    'odometer_km': e.odometerKm,
    'notes': e.notes,
  };

  static IncomeEntry _readIncome(Map<String, dynamic> raw, String vehicleId) =>
      IncomeEntry(
        id: '',
        vehicleId: vehicleId,
        date: _readDay(raw['date']),
        category: raw['category'] as String? ?? IncomeCategories.other,
        amount: _readDouble(raw['amount']) ?? 0,
        odometerKm: _readInt(raw['odometer_km']),
        notes: raw['notes'] as String?,
        createdBy: '',
      );

  static Map<String, dynamic> _rule(ReminderRule e) => {
    'service_type_key': e.serviceTypeKey,
    'interval_km': e.intervalKm,
    'interval_months': e.intervalMonths,
    'one_time': e.oneTime,
    'due_date': e.dueDate == null ? null : _day(e.dueDate!),
    'due_odometer_km': e.dueOdometerKm,
    'active': e.active,
  };

  /// The id is deliberately dropped: an id from another household names
  /// nothing here, and a rule carrying one would try to update a row that does
  /// not exist rather than being set up.
  static Map<String, dynamic> _tyres(TyreSet e) => {
    'name': e.name,
    'season': e.season.key,
    'fitted': e.fitted,
    'size': e.size,
    'storage_location': e.storageLocation,
    'fitted_at': e.fittedAt == null ? null : _day(e.fittedAt!),
    'retired_at': e.retiredAt == null ? null : _day(e.retiredAt!),
    'readings': [
      for (final reading in e.readings)
        {
          'date': _day(reading.date),
          'odometer_km': reading.odometerKm,
          'front_left_mm': reading.frontLeftMm,
          'front_right_mm': reading.frontRightMm,
          'rear_left_mm': reading.rearLeftMm,
          'rear_right_mm': reading.rearRightMm,
        },
    ],
  };

  static TyreSet _readTyres(Map<String, dynamic> raw, String vehicleId) {
    final readings = raw['readings'];
    return TyreSet(
      id: '',
      vehicleId: vehicleId,
      name: raw['name'] as String? ?? '',
      season: TyreSeason.fromKey(raw['season'] as String? ?? ''),
      fitted: raw['fitted'] as bool? ?? false,
      createdBy: '',
      size: raw['size'] as String?,
      storageLocation: raw['storage_location'] as String?,
      fittedAt: raw['fitted_at'] == null ? null : _readDay(raw['fitted_at']),
      retiredAt: raw['retired_at'] == null ? null : _readDay(raw['retired_at']),
      readings: [
        if (readings is List)
          for (final raw in readings)
            if (raw is Map<String, dynamic>)
              TyreReading(
                id: '',
                date: _readDay(raw['date']),
                odometerKm: _readInt(raw['odometer_km']),
                frontLeftMm: _readDouble(raw['front_left_mm']),
                frontRightMm: _readDouble(raw['front_right_mm']),
                rearLeftMm: _readDouble(raw['rear_left_mm']),
                rearRightMm: _readDouble(raw['rear_right_mm']),
              ),
      ],
    );
  }

  static ReminderRule _readRule(Map<String, dynamic> raw, String vehicleId) =>
      ReminderRule(
        id: '',
        vehicleId: vehicleId,
        serviceTypeKey: raw['service_type_key'] as String? ?? '',
        intervalKm: _readInt(raw['interval_km']),
        intervalMonths: _readInt(raw['interval_months']),
        oneTime: raw['one_time'] as bool? ?? false,
        dueDate: raw['due_date'] == null ? null : _readDay(raw['due_date']),
        dueOdometerKm: _readInt(raw['due_odometer_km']),
        active: raw['active'] as bool? ?? true,
      );
}
