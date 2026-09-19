import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../features/costs/providers/cost_providers.dart';
import '../../features/documents/providers/document_providers.dart';
import '../../features/fuel/providers/fuel_providers.dart';
import '../../features/household/providers/member_providers.dart';
import '../../features/income/providers/income_providers.dart';
import '../../features/maintenance/providers/maintenance_providers.dart';
import '../../features/observations/providers/observation_providers.dart';
import '../../features/odometer/providers/odometer_providers.dart';
import '../../features/parts/providers/vehicle_part_providers.dart';
import '../../features/trips/providers/fleet_trip_providers.dart';
import '../../features/trips/providers/route_providers.dart';
import '../../features/trips/providers/trip_providers.dart';
import '../../features/tyres/providers/tyre_providers.dart';
import '../../features/vehicles/providers/guest_pass_providers.dart';
import 'read_cache_providers.dart';

/// Refetches every list the read cache covers, family-wide.
///
/// The banner's Retry, app resume and a queue replay all want the same thing:
/// whatever was shown from a copy tried again against the server. Wholesale
/// rather than per stale key, because a key is a string and a provider is
/// not, and the list is short.
///
/// The marks go first. Invalidating refetches only a list something still
/// watches, so a mark left by a screen since closed would never be cleared
/// by the refetch; the lists on screen put their own mark back if the server
/// is still out of reach.
void invalidateReads(Ref ref) {
  ref.read(readCacheProvider).unmarkAll();
  _invalidate(ref.invalidate);
}

/// The same, from a widget: a [WidgetRef] is not a [Ref], and the list is
/// worth writing once.
void invalidateReadsFromWidget(WidgetRef ref) {
  ref.read(readCacheProvider).unmarkAll();
  _invalidate(ref.invalidate);
}

void _invalidate(void Function(ProviderOrFamily) invalidate) {
  invalidate(rawFuelEntriesProvider);
  invalidate(odometerEntriesProvider);
  invalidate(serviceEntriesProvider);
  invalidate(reminderRulesProvider);
  invalidate(serviceTypesProvider);
  invalidate(costEntriesProvider);
  invalidate(incomeEntriesProvider);
  invalidate(tripEntriesProvider);
  invalidate(allTripsProvider);
  invalidate(routesProvider);
  invalidate(observationsProvider);
  invalidate(vehicleDocumentsProvider);
  invalidate(tyreSetsProvider);
  invalidate(vehiclePartsProvider);
  invalidate(vehicleGuestPassesProvider);
  invalidate(myGuestPassesProvider);
  invalidate(garagePassesProvider);
  invalidate(membersProvider);
}
