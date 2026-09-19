import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../core/export/csv_export.dart';
import '../../core/format/unit_format.dart';
import '../../domain/company/assignment_resolution.dart';
import '../../domain/company/money_entry.dart';
import '../../domain/entities/cost_entry.dart';
import '../../domain/entities/fuel_entry.dart';
import '../../domain/entities/service_entry.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/vehicle_assignment.dart';
import '../../domain/export/export_file_name.dart';
import 'report_builder.dart';

/// Everything one car brings to the pack.
class VehiclePack {
  const VehiclePack({
    required this.vehicle,
    required this.fuel,
    required this.services,
    required this.costs,
    required this.receipts,
    required this.assignments,
    required this.driverNames,
  });

  final Vehicle vehicle;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<ReceiptImage> receipts;
  final List<VehicleAssignment> assignments;
  final Map<String, String> driverNames;
}

/// One zip for a month: a folder per car holding the ledger PDF with every
/// receipt appended, the receipts as the files they were uploaded as, and
/// the month's spreadsheets. "Everything must match per car" is the whole
/// design: the tax office samples per car, and an accountant wants each
/// entry next to its receipt.
Future<Uint8List> buildAccountantPack({
  required List<VehiclePack> cars,
  required ReportPeriod period,
  required String? letterhead,
  required AppLocalizations l10n,
  required UnitFormat format,
}) async {
  final archive = Archive();
  // The month as the file names carry it, from the day the pack starts on.
  final month = isoDay(period.from).substring(0, 7);
  final used = <String>{};

  void add(String name, List<int> bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  for (final car in cars) {
    // The plate is what the tax office files by; a car without one goes
    // under its name. Two cars would otherwise write over each other.
    final folder = uniqueName(
      vehicleSlug(car.vehicle.plate ?? car.vehicle.nickname),
      used,
    );
    bool inside(DateTime date) => period.contains(date);
    final fuel = [
      for (final e in car.fuel)
        if (inside(e.date)) e,
    ];
    final services = [
      for (final e in car.services)
        if (inside(e.date)) e,
    ];
    final costs = [
      for (final e in car.costs)
        if (inside(e.date)) e,
    ];
    final entries = {
      for (final entry in MoneyEntries.of(
        fuel: fuel,
        services: services,
        costs: costs,
      ))
        entry.id: entry,
    };
    // A receipt on an entry outside the month, or on a fill-up with no
    // total, has no row in the ledger and stays out of the folder with it.
    final receipts = [
      for (final receipt in car.receipts)
        if (entries.containsKey(receipt.attachment.entryId)) receipt,
    ];

    final ledger = await buildReport(
      kind: ReportKind.accountantPack,
      data: ReportData(
        vehicle: car.vehicle,
        currentOdometerKm: null,
        fuel: fuel,
        services: services,
        costs: costs,
        economy: const [],
        period: period,
        receipts: receipts,
        assignments: car.assignments,
        driverNames: car.driverNames,
        letterhead: letterhead,
      ),
      l10n: l10n,
      format: format,
    );
    add('$folder/$folder-$month-ledger.pdf', ledger);

    // The originals, named so a folder sorts by date and says what each is;
    // a second receipt on the same entry is the same name with `-2`. Stored
    // as they are: a photo is already compressed, and deflating one again
    // costs time for nothing.
    final taken = <String>{};
    for (final receipt in receipts) {
      final entry = entries[receipt.attachment.entryId]!;
      final extension = receipt.attachment.fileName.contains('.')
          ? receipt.attachment.fileName.split('.').last.toLowerCase()
          : 'bin';
      final stem = uniqueName(
        '${isoDay(entry.date)}-${entry.kind.key}-'
        '${entry.amount.toStringAsFixed(2)}',
        taken,
      );
      archive.addFile(
        ArchiveFile.noCompress(
          '$folder/$stem.$extension',
          receipt.bytes.length,
          receipt.bytes,
        ),
      );
    }

    // The same name the ledger prints beside the entry, so the sheet and
    // the PDF cannot disagree on who had the car: a departed driver is a
    // former member in both, never a blank.
    String driverOn(DateTime date) => AssignmentResolution.driverOf(
      car.assignments,
      names: car.driverNames,
      vehicleId: car.vehicle.id,
      on: date,
      former: l10n.companyFormerMember,
    );
    add(
      '$folder/$folder-$month-fuel.csv',
      utf8.encode(
        fuelEntriesToCsv(
          fuel,
          vehicleName: car.vehicle.nickname,
          driverOn: driverOn,
        ),
      ),
    );
    add(
      '$folder/$folder-$month-service.csv',
      utf8.encode(
        serviceEntriesToCsv(
          services,
          vehicleName: car.vehicle.nickname,
          driverOn: driverOn,
        ),
      ),
    );
    add(
      '$folder/$folder-$month-cost.csv',
      utf8.encode(
        costEntriesToCsv(
          costs,
          vehicleName: car.vehicle.nickname,
          driverOn: driverOn,
        ),
      ),
    );
  }

  return ZipEncoder().encodeBytes(archive);
}
