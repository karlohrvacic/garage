import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/maintenance/providers/service_entry_providers.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:riverpod/misc.dart' show Override;

/// Overrides every per-vehicle entry provider at once.
///
/// Anything that merges across entry kinds — the timeline, the odometer series,
/// the stats aggregate — resolves all of them, so a test that overrides only
/// the kinds it cares about reaches for a real Supabase client on the rest and
/// fails somewhere unrelated to what it was testing.
///
/// This exists so adding a seventh entry kind is one edit here rather than the
/// same edit in every harness that already merges six.
///
/// Passing **null** for a kind leaves that provider alone, for a harness that
/// supplies it another way — the maintenance tests drive service history
/// through a repository fake, and an empty override here would shadow it.
List<Override> vehicleEntryOverrides(
  String vehicleId, {
  List<FuelEntry>? fuel = const [],
  List<ServiceEntry>? services = const [],
  List<CostEntry>? costs = const [],
  List<OdometerEntry>? readings = const [],
  List<TripEntry>? trips = const [],
  List<IncomeEntry>? income = const [],
}) {
  return [
    if (fuel != null)
      rawFuelEntriesProvider(vehicleId).overrideWith((ref) async => fuel),
    if (services != null)
      serviceEntriesProvider(vehicleId).overrideWith((ref) async => services),
    if (costs != null)
      costEntriesProvider(vehicleId).overrideWith((ref) async => costs),
    if (readings != null)
      odometerEntriesProvider(vehicleId).overrideWith((ref) async => readings),
    if (trips != null)
      tripEntriesProvider(vehicleId).overrideWith((ref) async => trips),
    if (income != null)
      incomeEntriesProvider(vehicleId).overrideWith((ref) async => income),
  ];
}
