import 'package:csv/csv.dart';

import '../entities/cost_entry.dart';
import '../entities/vehicle.dart';

/// One fill-up row from a Fuelio backup, in Fuelio's own units (km, litres).
class FuelioFillUp {
  const FuelioFillUp({
    required this.date,
    required this.odometerKm,
    required this.volumeL,
    required this.fullTank,
    required this.missedFill,
    this.total,
    this.pricePerL,
    this.station,
    this.notes,
  });

  final DateTime date;
  final int odometerKm;
  final double volumeL;
  final bool fullTank;
  final bool missedFill;
  final double? total;
  final double? pricePerL;
  final String? station;
  final String? notes;
}

/// One expense row, category mapped to a Garage key.
class FuelioCost {
  const FuelioCost({
    required this.date,
    required this.category,
    required this.amount,
    this.odometerKm,
    this.notes,
  });

  final DateTime date;
  final String category;
  final double amount;
  final int? odometerKm;
  final String? notes;
}

/// A cost row recognised as a past service (title matched a service type, or
/// its Fuelio category was Service/Maintenance).
class FuelioService {
  const FuelioService({
    required this.date,
    required this.odometerKm,
    required this.serviceTypeKey,
    this.cost,
    this.notes,
  });

  final DateTime date;
  final int odometerKm;
  final String serviceTypeKey;
  final double? cost;
  final String? notes;
}

/// A recurring reminder Fuelio encoded in its Costs table (RepeatOdo /
/// RepeatMonths), mapped onto a Garage service type where the title allowed.
class FuelioReminder {
  const FuelioReminder({
    required this.title,
    required this.serviceTypeKey,
    this.repeatKm,
    this.repeatMonths,
    this.dueDate,
    this.dueOdometerKm,
  });

  final String title;

  /// Null when the title matched no known service type; the importer reports
  /// these instead of guessing.
  final String? serviceTypeKey;
  final int? repeatKm;
  final int? repeatMonths;

  /// Set on one-off reminders (Fuelio RemindDate / RemindOdo without repeat).
  final DateTime? dueDate;
  final int? dueOdometerKm;

  bool get isRecurring => repeatKm != null || repeatMonths != null;
}

/// The car a backup was exported for.
///
/// Fuelio exports one vehicle per file, in a `## Vehicle` section. Reading it
/// is what lets someone arriving from Fuelio import before they own anything
/// here — which is the only order that makes sense, since the import is how
/// their car gets created.
class FuelioVehicle {
  const FuelioVehicle({
    required this.name,
    this.make,
    this.model,
    this.year,
    this.plate,
    this.vin,
  });

  final String name;
  final String? make;
  final String? model;
  final int? year;
  final String? plate;
  final String? vin;
}

class FuelioBackup {
  const FuelioBackup({
    required this.fillUps,
    required this.costs,
    required this.services,
    required this.reminders,
    this.vehicle,
  });

  final List<FuelioFillUp> fillUps;
  final List<FuelioCost> costs;
  final List<FuelioService> services;
  final List<FuelioReminder> reminders;

  /// Null for an export that has no `## Vehicle` section — older versions, and
  /// files someone has trimmed by hand.
  final FuelioVehicle? vehicle;
}

/// Builds the car to create from a backup's `## Vehicle` section.
///
/// Tracking starts at the oldest reading in the file rather than today's:
/// a baseline set later than the imported history would place every fill-up
/// before the vehicle existed, and the economy series would start empty.
Vehicle vehicleFromFuelio(
  FuelioVehicle vehicle, {
  required String householdId,
  required String fuelTypeKey,
  required List<FuelioFillUp> fillUps,
  DateTime? now,
}) {
  final oldest = fillUps.isEmpty
      ? null
      : fillUps.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
  return Vehicle(
    // Assigned by the database on insert.
    id: '',
    householdId: householdId,
    nickname: vehicle.name,
    fuelTypeKey: fuelTypeKey,
    baselineOdometerKm: oldest?.odometerKm ?? 0,
    baselineDate: oldest?.date ?? (now ?? DateTime.now().toUtc()),
    make: vehicle.make,
    model: vehicle.model,
    year: vehicle.year,
    plate: vehicle.plate,
    vin: vehicle.vin,
  );
}

/// Cleans a value as Fuelio wrote it.
///
/// Its notes carry a non-breaking space before the currency symbol
/// ("Discount: 1,25\u00a0\u20ac") and sometimes several discounts separated by
/// newlines inside one CSV field. Carried through verbatim, both read as
/// artefacts: an invisible character that breaks nothing but copies oddly, and
/// a note that renders as one squashed line or blows up a row's height.
String tidyCell(String raw) {
  return raw
      .replaceAll('\u00a0', ' ')
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join(' · ')
      .trim();
}

/// Maps a Fuelio cost-category name (user-defined, any language) onto a
/// Garage category key. Falls back to `other` — an import must never drop a
/// row over a label it does not recognise.
String mapFuelioCategory(String name) {
  final lower = name.toLowerCase();
  bool has(List<String> needles) =>
      needles.any((needle) => lower.contains(needle));
  if (has(['regist'])) {
    return CostCategories.registration;
  }
  // Kasko before the general insurance test: a title reading "Kasko
  // osiguranje" contains both, and the more specific one is the true answer.
  if (has(['kasko', 'comprehensive'])) {
    return CostCategories.insuranceComprehensive;
  }
  if (has(['osigur', 'insur'])) {
    return CostCategories.insurance;
  }
  if (has(['park'])) {
    return CostCategories.parking;
  }
  if (has(['cestarin', 'toll', 'vinjet', 'vignette'])) {
    return CostCategories.toll;
  }
  if (has(['pranje', 'wash'])) {
    return CostCategories.wash;
  }
  if (has(['kazna', 'fine', 'penal', 'ticket'])) {
    return CostCategories.fine;
  }
  if (has(['oprema', 'equip', 'tuning'])) {
    return CostCategories.equipment;
  }
  return CostCategories.other;
}

/// Maps a Fuelio cost/reminder title onto a Garage service-type key, or null.
/// Croatian and English needles, matched loosest-last.
String? mapFuelioServiceTitle(String title) {
  final lower = title.toLowerCase();
  bool has(List<String> needles) =>
      needles.any((needle) => lower.contains(needle));
  if (has(['svjećic', 'svjecic', 'spark'])) {
    return 'service_spark_plugs';
  }
  if (has(['ulja mjenja', 'mjenjač', 'mjenjac', 'transmission'])) {
    return 'service_transmission_oil';
  }
  if (has(['rashladn', 'coolant'])) {
    return 'service_coolant';
  }
  if (has(['kočione teku', 'kocione teku', 'brake fluid'])) {
    return 'service_brake_fluid';
  }
  if (has(['filtra zraka', 'filter zraka', 'air filter'])) {
    return 'service_air_filter';
  }
  // "klime" alone is ambiguous: Fuelio uses it for the cabin filter
  // ("filtar klime") and for servicing the air conditioning itself. Only the
  // filter wording claims it here; the bare word falls through to the A/C
  // service below.
  if (has([
    'putničkog',
    'putnickog',
    'pelud',
    'cabin',
    'filtar klime',
    'filter klime',
    'filtra klime',
  ])) {
    return 'service_cabin_filter';
  }
  if (has(['filtra ulja', 'filter ulja', 'oil filter'])) {
    return 'service_oil_filter';
  }
  if (has(['ulj', 'oil'])) {
    return 'service_oil_change';
  }
  // Belts before the loose 'remen'/'belt' catch below. Fuelio's own Croatian
  // preset for the accessory belt is "Zamjena remena za pogon dodatnih
  // agregata i napinjača"; matching "remen" alone filed it as the timing belt,
  // which is a different part on a different interval.
  if (has([
    'pogon dodatnih agregata',
    'napinjač',
    'napinjac',
    'klinasti',
    'serpentine',
    'accessory belt',
    'auxiliary belt',
    'drive belt',
  ])) {
    return 'service_serpentine_belt';
  }
  if (has(['zupčast', 'zupcast', 'timing'])) {
    return 'service_timing_belt';
  }
  if (has(['grijač', 'grijac', 'glow'])) {
    return 'service_glow_plugs';
  }
  if (has(['filtra goriva', 'filter goriva', 'fuel filter'])) {
    return 'service_fuel_filter';
  }
  if (has(['adblue'])) {
    return 'service_adblue';
  }
  if (has(['dpf', 'particulate'])) {
    return 'service_dpf';
  }
  if (has(['kvačil', 'kvacil', 'clutch'])) {
    return 'service_clutch';
  }
  if (has(['diferencijal', 'differential'])) {
    return 'service_differential_oil';
  }
  if (has(['vodena pump', 'water pump'])) {
    return 'service_water_pump';
  }
  if (has(['amortizer', 'shock absorber'])) {
    return 'service_shock_absorbers';
  }
  if (has(['geometrij', 'alignment', 'trap'])) {
    return 'service_wheel_alignment';
  }
  if (has(['klim', 'air conditioning', 'a/c service'])) {
    return 'service_ac_service';
  }
  if (has(['žarulj', 'zarulj', 'bulb'])) {
    return 'service_bulbs';
  }
  if (has(['disk', 'disc'])) {
    return lower.contains('straž') ||
            lower.contains('straz') ||
            lower.contains('rear')
        ? 'service_brake_discs_rear'
        : 'service_brake_discs_front';
  }
  if (has(['bubnj', 'drum'])) {
    return 'service_brake_drums_rear';
  }
  if (has(['remen', 'belt'])) {
    return 'service_timing_belt';
  }
  if (has(['gume', 'gumu', 'tire', 'tyre'])) {
    return 'service_tire_swap_seasonal';
  }
  if (has(['akumulator', 'battery'])) {
    return 'service_battery';
  }
  if (has(['brisač', 'brisac', 'wiper'])) {
    return 'service_wipers';
  }
  if (has(['tehnički', 'tehnicki', 'inspection'])) {
    return 'service_technical_inspection';
  }
  if (has(['kočnic', 'kocnic', 'brake'])) {
    return 'service_brake_pads_front';
  }
  return null;
}

/// Parses a Fuelio CSV backup. The file is section-based (`## Log`,
/// `## Costs`, `## CostCategories`, ...), each section with its own header
/// row. Column positions are resolved from the header names because Fuelio
/// has added and renamed columns over the years (`Data`/`Date`,
/// `Odo (km)`/`Odo`).
///
/// Fuelio's Costs section triple-books: real expenses, past services, and
/// reminders all live there. Rows are split three ways:
/// - `RepeatOdo`/`RepeatMonths` > 0 → a recurring [FuelioReminder];
/// - past rows whose title/category reads as a service → [FuelioService];
/// - past rows with a positive amount (and not income) → [FuelioCost].
FuelioBackup parseFuelioBackup(String csv, {DateTime? now}) {
  final rows = Csv().decode(csv.replaceAll('\r\n', '\n'));
  final today = now ?? DateTime.now().toUtc();

  final fillUps = <FuelioFillUp>[];
  final services = <FuelioService>[];
  final reminders = <FuelioReminder>[];
  final rawCosts =
      <
        ({
          DateTime date,
          double amount,
          String? categoryId,
          String title,
          String? notes,
          int? odometerKm,
          bool income,
        })
      >[];
  final categoryNames = <String, String>{};
  FuelioVehicle? vehicle;

  String? section;
  List<String>? header;

  int? col(List<String> names) {
    if (header == null) {
      return null;
    }
    // Exact match wins before prefix match: "Cost" must resolve to the
    // "Cost" column, not "CostTitle".
    for (var i = 0; i < header.length; i++) {
      if (names.contains(header[i].toLowerCase())) {
        return i;
      }
    }
    for (var i = 0; i < header.length; i++) {
      final cell = header[i].toLowerCase();
      if (names.any((name) => cell.startsWith('$name '))) {
        return i;
      }
    }
    return null;
  }

  String? cell(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) {
      return null;
    }
    final value = tidyCell(row[index].toString());
    return value.isEmpty ? null : value;
  }

  double? parseNum(String? raw) =>
      raw == null ? null : double.tryParse(raw.replaceAll(',', '.'));

  DateTime? parseDate(String? raw) {
    if (raw == null) {
      return null;
    }
    final iso = DateTime.tryParse(raw);
    if (iso != null) {
      return DateTime.utc(iso.year, iso.month, iso.day);
    }
    // Older exports use dd.MM.yyyy.
    final match = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(raw);
    if (match == null) {
      return null;
    }
    return DateTime.utc(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }

  for (final row in rows) {
    if (row.isEmpty) {
      continue;
    }
    final first = row.first.toString().trim();
    if (first.startsWith('## ')) {
      section = first.substring(3).toLowerCase();
      header = null;
      continue;
    }
    if (section == null) {
      continue;
    }
    if (header == null) {
      header = row.map((cellValue) => cellValue.toString().trim()).toList();
      continue;
    }

    switch (section) {
      case 'vehicle':
        // One vehicle per export, so the first row wins; a second would be a
        // file someone has stitched together by hand.
        final name = cell(row, col(['name']));
        if (name != null && vehicle == null) {
          vehicle = FuelioVehicle(
            name: name,
            make: cell(row, col(['make'])),
            model: cell(row, col(['model'])),
            year: parseNum(cell(row, col(['year'])))?.round(),
            plate: cell(row, col(['plate'])),
            vin: cell(row, col(['vin'])),
          );
        }
      case 'log':
        final date = parseDate(cell(row, col(['data', 'date'])));
        final odometer = parseNum(cell(row, col(['odo'])));
        final volume = parseNum(cell(row, col(['fuel'])));
        if (date == null || odometer == null || volume == null) {
          continue;
        }
        final pricePerL = parseNum(cell(row, col(['volumeprice'])));
        final total = parseNum(cell(row, col(['price'])));
        fillUps.add(
          FuelioFillUp(
            date: date,
            odometerKm: odometer.round(),
            volumeL: volume,
            fullTank: cell(row, col(['full'])) == '1',
            missedFill: cell(row, col(['missed'])) == '1',
            total: total == 0 ? null : total,
            pricePerL: pricePerL == 0 ? null : pricePerL,
            station: cell(row, col(['city'])),
            notes: cell(row, col(['notes'])),
          ),
        );
      case 'costcategories':
        final id = cell(row, col(['costtypeid', 'id']));
        final name = cell(row, col(['name']));
        if (id != null && name != null) {
          categoryNames[id] = name;
        }
      case 'costs':
        final title = cell(row, col(['costtitle'])) ?? '';
        final repeatKm = parseNum(cell(row, col(['repeatodo'])))?.round();
        final repeatMonths = parseNum(
          cell(row, col(['repeatmonths'])),
        )?.round();
        if ((repeatKm ?? 0) > 0 || (repeatMonths ?? 0) > 0) {
          reminders.add(
            FuelioReminder(
              title: title,
              serviceTypeKey: mapFuelioServiceTitle(title),
              repeatKm: (repeatKm ?? 0) > 0 ? repeatKm : null,
              repeatMonths: (repeatMonths ?? 0) > 0 ? repeatMonths : null,
            ),
          );
          continue;
        }

        // A non-repeating remind target is a one-off reminder. The same row
        // may also carry a past cost/service (a done job with the next one
        // pinned), so parsing continues below.
        final remindDate = parseDate(cell(row, col(['reminddate'])));
        final remindOdo = parseNum(cell(row, col(['remindodo'])))?.round();
        if ((remindDate != null && remindDate.isAfter(today)) ||
            (remindOdo ?? 0) > 0) {
          reminders.add(
            FuelioReminder(
              title: title,
              serviceTypeKey: mapFuelioServiceTitle(title),
              dueDate: remindDate != null && remindDate.isAfter(today)
                  ? remindDate
                  : null,
              dueOdometerKm: (remindOdo ?? 0) > 0 ? remindOdo : null,
            ),
          );
        }

        final date = parseDate(cell(row, col(['data', 'date'])));
        if (date == null || date.isAfter(today)) {
          continue;
        }
        final amount = parseNum(cell(row, col(['cost']))) ?? 0;
        final income = cell(row, col(['isincome'])) == '1' || amount < 0;
        final odometer = parseNum(cell(row, col(['odo'])))?.round();
        final notes = cell(row, col(['notes']));
        final categoryId = cell(row, col(['costtypeid']));
        final categoryName = categoryNames[categoryId] ?? '';

        final serviceKey = mapFuelioServiceTitle(title);
        final looksLikeService =
            serviceKey != null ||
            mapFuelioCategory(categoryName) == CostCategories.other &&
                RegExp(
                  'servi|mainten|održavan|odrzavan',
                ).hasMatch(categoryName.toLowerCase());
        if (!income && looksLikeService && odometer != null && odometer > 0) {
          services.add(
            FuelioService(
              date: date,
              odometerKm: odometer,
              serviceTypeKey: serviceKey ?? 'service_oil_change',
              cost: amount > 0 ? amount : null,
              notes: [title, ?notes].join(' · '),
            ),
          );
          continue;
        }

        if (income || amount <= 0) {
          continue;
        }
        rawCosts.add((
          date: date,
          amount: amount,
          categoryId: categoryId,
          title: title,
          notes: notes,
          odometerKm: odometer == 0 ? null : odometer,
          income: income,
        ));
    }
  }

  // Category names resolve after the loop: section order varies between
  // Fuelio versions, and Costs may precede CostCategories in the file.
  final costs = [
    for (final raw in rawCosts)
      FuelioCost(
        date: raw.date,
        category: mapFuelioCategory(categoryNames[raw.categoryId] ?? raw.title),
        amount: raw.amount,
        odometerKm: raw.odometerKm,
        notes: switch ([
          if (raw.title.isNotEmpty) raw.title,
          ?raw.notes,
        ].join(' · ')) {
          '' => null,
          final joined => joined,
        },
      ),
  ];

  return FuelioBackup(
    fillUps: fillUps,
    costs: costs,
    services: services,
    reminders: reminders,
    vehicle: vehicle,
  );
}
