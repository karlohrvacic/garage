import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:riverpod/misc.dart' show Override;

/// A garage on the plan, for a sheet test that wants the driver line.
const companyGarage = Household(id: 'h1', name: 'Prijevoz', plan: 'company');

/// The assignment log the sheets resolve a driver against, and the names
/// that turn its user ids into people.
///
/// Left to its defaults, Ana has had `v1` since New Year, which covers
/// whatever day a sheet opens on. One helper because four sheets show the
/// same line, and the shape of the log is not what any of their tests is
/// about.
List<Override> driverLog({
  List<VehicleAssignment>? assignments,
  Map<String, String> names = const {'u2': 'Ana'},

  /// The fetch itself, for a log that has not arrived or one whose fetch
  /// failed. Wins over [assignments].
  Future<List<VehicleAssignment>> Function()? fetch,
}) {
  final log =
      assignments ??
      [
        VehicleAssignment(
          id: 'a1',
          vehicleId: 'v1',
          userId: 'u2',
          fromDate: DateTime.utc(2026, 1, 1),
        ),
      ];
  return [
    fleetAssignmentsProvider.overrideWith(
      (ref) => fetch?.call() ?? Future.value(log),
    ),
    memberNamesProvider.overrideWith((ref) async => names),
  ];
}
