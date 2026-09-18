import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import '../fuel/providers/fuel_providers.dart';
import '../fuel/widgets/fuel_entry_sheet.dart';
import '../maintenance/providers/maintenance_providers.dart';
import '../maintenance/widgets/service_entry_sheet.dart';
import '../costs/providers/cost_providers.dart';
import '../costs/widgets/cost_entry_sheet.dart';
import '../odometer/providers/odometer_providers.dart';
import '../odometer/widgets/odometer_entry_sheet.dart';
import '../trips/providers/trip_providers.dart';
import '../trips/widgets/trip_entry_sheet.dart';
import '../income/providers/income_providers.dart';
import '../income/widgets/income_entry_sheet.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/failure_message.dart';
import 'providers/timeline_providers.dart';

/// Opens the entry a timeline row stands for, in the sheet it was logged
/// with: the timeline's rows and the dashboard's recent ones both lead here.
///
/// It used to push the *screen* the entry lives on — the fuel log, the vehicle
/// page — which made the app's only search surface answer "find that thing I
/// logged" with a list you have to search again. Three of the six kinds landed
/// on `/vehicles/:id`, and on its first tab rather than the one holding the
/// entry. Every sibling list already opened the sheet directly; this was the
/// exception.
Future<void> openTimelineEntry(
  BuildContext context,
  WidgetRef ref,
  TimelineItem item,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final vehicleId = item.vehicleId;

  /// The first entry of a kind matching this row, or null.
  Future<T?> find<T>(Future<List<T>> entries, String Function(T) idOf) async {
    return (await entries).where((e) => idOf(e) == item.entryId).firstOrNull;
  }

  try {
    switch (item.kind) {
      case TimelineKind.fuel:
        final entry = await find(
          ref.read(rawFuelEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showFuelEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.service:
        final entry = await find(
          ref.read(serviceEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showServiceEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.cost:
        final entry = await find(
          ref.read(costEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showCostEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.odometer:
        final entry = await find(
          ref.read(odometerEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showOdometerEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.trip:
        final entry = await find(
          ref.read(tripEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showTripEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.income:
        final entry = await find(
          ref.read(incomeEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showIncomeEntrySheet(context, vehicleId, existing: entry);
        }
    }
  } catch (error) {
    // A tap handler that throws tells the user nothing and reaches no screen.
    // Through failureMessage so the cause is recorded rather than dropped.
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
  }
}
