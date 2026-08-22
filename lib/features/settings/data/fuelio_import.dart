import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/import/fuelio_backup.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';

class FuelioImportResult {
  const FuelioImportResult({
    required this.fillUps,
    required this.costs,
    required this.services,
    required this.reminders,
    required this.skippedReminders,
  });

  final int fillUps;
  final int costs;
  final int services;
  final int reminders;

  /// Reminder titles that matched no Garage service type and were not
  /// imported.
  final List<String> skippedReminders;
}

/// Writes a parsed Fuelio backup into one vehicle. Re-running the same import
/// is safe: rows already present are matched by their natural keys and
/// skipped, and reminder rules upsert per service type.
Future<FuelioImportResult> importFuelioBackup({
  required WidgetRef ref,
  required String vehicleId,
  required FuelioBackup backup,

  /// Where the fuel was bought, for rows that do not say.
  ///
  /// Fuelio's export has a `City` and a `StationID` column and leaves both
  /// empty, so an import lands every fill-up with no station and the only way
  /// to fix it was to edit them one at a time. Asked once at import instead.
  ///
  /// A **fallback**, never a correction: a row that named its own station
  /// keeps it. Overwriting would discard the one fact the file did carry.
  String? defaultStation,
}) async {
  final fuelRepository = ref.read(fuelRepositoryProvider);
  final costRepository = ref.read(costRepositoryProvider);
  final maintenanceRepository = ref.read(maintenanceRepositoryProvider);

  final existingFuel = await fuelRepository.forVehicle(vehicleId);
  final existingFuelKeys = {
    for (final entry in existingFuel) '${entry.date}|${entry.odometerKm}',
  };
  var importedFills = 0;
  for (final fill in backup.fillUps) {
    if (existingFuelKeys.contains('${fill.date}|${fill.odometerKm}')) {
      continue;
    }
    await fuelRepository.add(
      FuelEntry(
        id: '',
        vehicleId: vehicleId,
        date: fill.date,
        odometerKm: fill.odometerKm,
        volumeL: fill.volumeL,
        pricePerL:
            fill.pricePerL ??
            (fill.total != null && fill.volumeL > 0
                ? fill.total! / fill.volumeL
                : null),
        total: fill.total,
        fullTank: fill.fullTank,
        missedFill: fill.missedFill,
        station: _station(fill.station, defaultStation),
        notes: fill.notes,
        createdBy: '',
      ),
    );
    importedFills++;
  }

  final existingServices = await maintenanceRepository.serviceEntriesForVehicle(
    vehicleId,
  );
  final existingServiceKeys = {
    for (final entry in existingServices)
      '${entry.date}|${entry.odometerKm}|${entry.serviceTypeKeys.join(',')}',
  };
  var importedServices = 0;
  for (final service in backup.services) {
    final key =
        '${service.date}|${service.odometerKm}|${service.serviceTypeKey}';
    if (existingServiceKeys.contains(key)) {
      continue;
    }
    await maintenanceRepository.addServiceEntry(
      ServiceEntry(
        id: '',
        vehicleId: vehicleId,
        date: service.date,
        odometerKm: service.odometerKm,
        serviceTypeKeys: [service.serviceTypeKey],
        cost: service.cost,
        notes: service.notes,
        createdBy: '',
      ),
    );
    importedServices++;
  }

  final existingCosts = await costRepository.forVehicle(vehicleId);
  final existingCostKeys = {
    for (final entry in existingCosts)
      '${entry.date}|${entry.category}|${entry.amount}',
  };
  var importedCosts = 0;
  for (final cost in backup.costs) {
    if (existingCostKeys.contains(
      '${cost.date}|${cost.category}|${cost.amount}',
    )) {
      continue;
    }
    await costRepository.add(
      CostEntry(
        id: '',
        vehicleId: vehicleId,
        date: cost.date,
        category: cost.category,
        amount: cost.amount,
        odometerKm: cost.odometerKm,
        notes: cost.notes,
        createdBy: '',
      ),
    );
    importedCosts++;
  }

  var importedReminders = 0;
  final skippedReminders = <String>[];
  final existingRules = await maintenanceRepository.rulesForVehicle(vehicleId);
  for (final reminder in backup.reminders) {
    final serviceTypeKey = reminder.serviceTypeKey;
    if (serviceTypeKey == null) {
      skippedReminders.add(reminder.title);
      continue;
    }
    if (reminder.isRecurring) {
      await maintenanceRepository.upsertRule(
        ReminderRule(
          id: '',
          vehicleId: vehicleId,
          serviceTypeKey: serviceTypeKey,
          intervalKm: reminder.repeatKm,
          intervalMonths: reminder.repeatMonths,
          active: true,
        ),
      );
      importedReminders++;
      continue;
    }
    final duplicate = existingRules.any(
      (rule) =>
          rule.oneTime &&
          rule.serviceTypeKey == serviceTypeKey &&
          rule.dueDate == reminder.dueDate &&
          rule.dueOdometerKm == reminder.dueOdometerKm,
    );
    if (duplicate) {
      continue;
    }
    await maintenanceRepository.upsertRule(
      ReminderRule(
        id: '',
        vehicleId: vehicleId,
        serviceTypeKey: serviceTypeKey,
        oneTime: true,
        dueDate: reminder.dueDate,
        dueOdometerKm: reminder.dueOdometerKm,
        active: true,
      ),
    );
    importedReminders++;
  }

  ref
    ..invalidate(rawFuelEntriesProvider(vehicleId))
    ..invalidate(costEntriesProvider(vehicleId))
    ..invalidate(serviceEntriesProvider(vehicleId))
    ..invalidate(reminderRulesProvider(vehicleId))
    ..invalidate(vehicleProjectionsProvider(vehicleId));

  return FuelioImportResult(
    fillUps: importedFills,
    costs: importedCosts,
    services: importedServices,
    reminders: importedReminders,
    skippedReminders: skippedReminders,
  );
}

/// The row's own station, then the one asked for at import, then nothing.
/// Blank is nothing: an untouched text field must not write empty strings over
/// a column that means "unknown" when it is null.
String? _station(String? own, String? fallback) {
  for (final candidate in [own, fallback]) {
    final trimmed = candidate?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
