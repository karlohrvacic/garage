import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/unit_format.dart';

import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/entities/income_entry.dart';
import '../../../domain/entities/odometer_entry.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../../domain/import/csv_import.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../trips/providers/fleet_trip_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// Units the numbers in the file are written in.
///
/// Asked rather than assumed. A file exported from an app set to miles carries
/// miles, and importing those as kilometres understates every distance by 40%
/// in a way nothing later can detect.
class CsvUnits {
  const CsvUnits({
    this.milesToKm = false,
    this.gallonsToLitres = false,
    this.gallon = VolumeUnit.usGallon,
  });

  final bool milesToKm;
  final bool gallonsToLitres;

  /// Which gallon the file is written in. A household that reads imperial
  /// gallons means those when it says a file is in gallons, and taking them
  /// for US ones understates every volume by a fifth.
  final VolumeUnit gallon;

  double get _litres => litresPerGallon(gallon);

  double distanceKm(double value) => milesToKm ? value * 1.609344 : value;

  double volumeL(double value) => gallonsToLitres ? value * _litres : value;

  /// A price is per unit of volume, so it converts the other way: a file in
  /// gallons quotes a price per gallon. Converting the volume alone leaves an
  /// entry that contradicts itself — 10 gallons at 4.20 "per litre" totalling
  /// 42 — and puts every price-per-litre figure out by nearly four times.
  double pricePerVolume(double value) =>
      gallonsToLitres ? value / _litres : value;
}

class CsvWriteResult {
  const CsvWriteResult({required this.written, required this.skipped});

  final int written;

  /// Rows that matched something already in the log and were left alone, so
  /// running the same import twice does not double a household's history.
  final int skipped;
}

/// Writes rows built by [CsvImport] into one vehicle.
///
/// Re-runnable by design: every kind is matched against what is already stored
/// by the natural key a human would use — date plus the thing that identifies
/// it — and a match is skipped rather than written again. Somebody who imports
/// the same file twice, which is what happens when the first attempt looked
/// like it failed, ends up with one copy.
Future<CsvWriteResult> writeCsvRows({
  required WidgetRef ref,
  required String vehicleId,
  required CsvEntryKind kind,
  required List<Map<String, Object>> rows,
  CsvUnits units = const CsvUnits(),
}) async {
  var written = 0;
  var skipped = 0;

  Future<void> write(
    String key,
    Set<String> existing,
    Future<void> Function() add,
  ) async {
    if (existing.contains(key)) {
      skipped++;
      return;
    }
    existing.add(key);
    await add();
    written++;
  }

  switch (kind) {
    case CsvEntryKind.fuel:
      final repository = ref.read(fuelRepositoryProvider);
      final existing = {
        for (final e in await repository.forVehicle(vehicleId))
          '${e.date}|${e.odometerKm}',
      };
      for (final row in rows) {
        final date = row['date']! as DateTime;
        final odometerKm = units
            .distanceKm((row['odometer']! as int).toDouble())
            .round();
        await write('$date|$odometerKm', existing, () {
          return repository.add(
            FuelEntry(
              id: '',
              vehicleId: vehicleId,
              date: date,
              odometerKm: odometerKm,
              volumeL: units.volumeL((row['volume']! as num).toDouble()),
              pricePerL: switch (row['pricePerUnit']) {
                final num price => units.pricePerVolume(price.toDouble()),
                _ => null,
              },
              total: (row['total'] as num?)?.toDouble(),
              // A file that does not say assumes a full tank: that is what a
              // fill-up usually is, and it is the assumption that lets the
              // economy algorithm produce anything at all.
              fullTank: row['fullTank'] as bool? ?? true,
              missedFill: false,
              station: row['station'] as String?,
              notes: row['notes'] as String?,
              createdBy: '',
            ),
          );
        });
      }

    case CsvEntryKind.cost:
      final repository = ref.read(costRepositoryProvider);
      final existing = {
        for (final e in await repository.forVehicle(vehicleId))
          '${e.date}|${e.amount}|${e.category}',
      };
      for (final row in rows) {
        final date = row['date']! as DateTime;
        final amount = (row['amount']! as num).toDouble();
        final category = _costCategory(row['category'] as String?);
        await write('$date|$amount|$category', existing, () {
          return repository.add(
            CostEntry(
              id: '',
              vehicleId: vehicleId,
              date: date,
              category: category,
              amount: amount,
              odometerKm: _odometer(row, units),
              notes: _notesWithCategory(row, category),
              createdBy: '',
            ),
          );
        });
      }

    case CsvEntryKind.service:
      final repository = ref.read(maintenanceRepositoryProvider);
      final existing = {
        for (final e in await repository.serviceEntriesForVehicle(vehicleId))
          '${e.date}|${e.odometerKm}',
      };
      for (final row in rows) {
        final date = row['date']! as DateTime;
        final odometerKm = units
            .distanceKm((row['odometer']! as int).toDouble())
            .round();
        await write('$date|$odometerKm', existing, () {
          return repository.addServiceEntry(
            ServiceEntry(
              id: '',
              vehicleId: vehicleId,
              date: date,
              odometerKm: odometerKm,
              // Unmatched work becomes "other" with its own words kept in the
              // notes, rather than being dropped for not being one of ours.
              serviceTypeKeys: const ['service_other'],
              cost: (row['cost'] as num?)?.toDouble(),
              shop: row['shop'] as String?,
              notes: _notesWithCategory(row, row['type'] as String?),
              createdBy: '',
            ),
          );
        });
      }

    case CsvEntryKind.odometer:
      final repository = ref.read(odometerRepositoryProvider);
      final existing = {
        for (final e in await repository.forVehicle(vehicleId))
          '${e.date}|${e.odometerKm}',
      };
      for (final row in rows) {
        final date = row['date']! as DateTime;
        final odometerKm = units
            .distanceKm((row['odometer']! as int).toDouble())
            .round();
        await write('$date|$odometerKm', existing, () {
          return repository.add(
            OdometerEntry(
              id: '',
              vehicleId: vehicleId,
              date: date,
              odometerKm: odometerKm,
              notes: row['notes'] as String?,
              createdBy: '',
            ),
          );
        });
      }

    case CsvEntryKind.trip:
      final repository = ref.read(tripRepositoryProvider);
      final existing = {
        for (final e in await repository.forVehicle(vehicleId))
          '${e.date}|${e.distanceKm}',
      };
      for (final row in rows) {
        final date = row['date']! as DateTime;
        final distanceKm = units.distanceKm(
          (row['distance']! as num).toDouble(),
        );
        await write('$date|$distanceKm', existing, () {
          return repository.add(
            TripEntry(
              id: '',
              vehicleId: vehicleId,
              date: date,
              distanceKm: distanceKm,
              purpose: (row['business'] as bool? ?? false)
                  ? TripPurpose.business
                  : TripPurpose.private,
              title: row['title'] as String?,
              fromPlace: row['from'] as String?,
              toPlace: row['to'] as String?,
              minutes: row['minutes'] as int?,
              notes: row['notes'] as String?,
              createdBy: '',
            ),
          );
        });
      }

    case CsvEntryKind.income:
      final repository = ref.read(incomeRepositoryProvider);
      final existing = {
        for (final e in await repository.forVehicle(vehicleId))
          '${e.date}|${e.amount}|${e.category}',
      };
      for (final row in rows) {
        final date = row['date']! as DateTime;
        final amount = (row['amount']! as num).toDouble();
        final category = _incomeCategory(row['category'] as String?);
        await write('$date|$amount|$category', existing, () {
          return repository.add(
            IncomeEntry(
              id: '',
              vehicleId: vehicleId,
              date: date,
              category: category,
              amount: amount,
              odometerKm: _odometer(row, units),
              notes: _notesWithCategory(row, category),
              createdBy: '',
            ),
          );
        });
      }
  }

  _invalidate(ref, vehicleId);
  return CsvWriteResult(written: written, skipped: skipped);
}

int? _odometer(Map<String, Object> row, CsvUnits units) {
  final value = row['odometer'] as int?;
  return value == null ? null : units.distanceKm(value.toDouble()).round();
}

/// Keeps the file's own word for a category alongside the key it was mapped
/// to, so an import never silently loses what the row said it was.
String? _notesWithCategory(Map<String, Object> row, String? original) {
  final notes = row['notes'] as String?;
  if (original == null || original.isEmpty) {
    return notes;
  }
  return notes == null || notes.isEmpty ? original : '$original — $notes';
}

/// Maps a file's word for a category onto one of ours, falling back to
/// `other`. Matching is loose because "Insurance", "insurance " and
/// "INSURANCE" are the same category to everyone but a string comparison.
String _costCategory(String? raw) {
  final key = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (key.isEmpty) {
    return CostCategories.other;
  }
  for (final candidate in CostCategories.all) {
    if (key.contains(candidate.replaceAll('_', ''))) {
      return candidate;
    }
  }
  return switch (key) {
    'tax' || 'roadtax' => CostCategories.registration,
    'tolls' => CostCategories.toll,
    'carwash' || 'washing' => CostCategories.wash,
    'fines' || 'penalty' => CostCategories.fine,
    _ => CostCategories.other,
  };
}

String _incomeCategory(String? raw) {
  final key = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (key.isEmpty) {
    return IncomeCategories.other;
  }
  for (final candidate in IncomeCategories.all) {
    if (key.contains(candidate.replaceAll('_', ''))) {
      return candidate;
    }
  }
  return switch (key) {
    'sale' || 'sold' => IncomeCategories.vehicleSale,
    'uber' || 'bolt' || 'taxi' => IncomeCategories.transportApp,
    _ => IncomeCategories.other,
  };
}

/// Everything an import can have changed. Broad on purpose: an import touches
/// one kind but moves the odometer, the projections and the statistics with it.
void _invalidate(WidgetRef ref, String vehicleId) {
  ref
    ..invalidate(rawFuelEntriesProvider(vehicleId))
    ..invalidate(costEntriesProvider(vehicleId))
    ..invalidate(serviceEntriesProvider(vehicleId))
    ..invalidate(odometerEntriesProvider(vehicleId))
    ..invalidate(tripEntriesProvider(vehicleId))
    ..invalidate(incomeEntriesProvider(vehicleId))
    ..invalidate(allTripsProvider)
    ..invalidate(vehicleProjectionsProvider(vehicleId))
    ..invalidate(currentOdometerProvider(vehicleId));
}
