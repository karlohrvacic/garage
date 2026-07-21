import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';

/// A kind of service. Built-in presets ship with the app's database; a
/// household may add its own. Intervals here are only starting suggestions —
/// there is no affordable EU-wide source of manufacturer schedules, so the
/// user is always free to override them per vehicle.
class ServiceType {
  const ServiceType({
    required this.key,
    this.defaultIntervalKm,
    this.defaultIntervalMonths,
    this.isStatutory = false,
    this.countryCode,
  });

  final String key;
  final int? defaultIntervalKm;
  final int? defaultIntervalMonths;
  final bool isStatutory;
  final String? countryCode;
}

abstract interface class MaintenanceRepository {
  Future<List<ServiceType>> serviceTypes();

  Future<List<ReminderRule>> rulesForVehicle(String vehicleId);

  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId);

  Future<void> upsertRule(ReminderRule rule);

  Future<void> deleteRule(String id);

  Future<void> addServiceEntry(ServiceEntry entry);
}
