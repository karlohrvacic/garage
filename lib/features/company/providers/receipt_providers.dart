import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/company/missing_receipts.dart';
import '../../../domain/company/money_entry.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import 'reimbursement_providers.dart';

/// The month's money entries with nothing attached, across the fleet.
/// Keyed by the month (UTC, day 1), so the console can ask for different
/// ones.
final missingReceiptsProvider =
    FutureProvider.family<List<MoneyEntry>, DateTime>((ref, month) async {
      final entries = await ref.watch(fleetMoneyEntriesProvider.future);
      final withReceipts = await ref.watch(
        entriesWithAttachmentsProvider.future,
      );
      return MissingReceipts.inMonth(
        entries: entries,
        entryIdsWithAttachments: withReceipts,
        month: month,
      );
    });

/// The same for one car, from the car's own three lists: the card on a
/// car's page has no business reading every other car's tables to draw
/// itself, which on a thirty-car fleet was ninety requests for one tab.
final vehicleMissingReceiptsProvider =
    FutureProvider.family<
      List<MoneyEntry>,
      ({String vehicleId, DateTime month})
    >((ref, key) async {
      final fuel = await ref.watch(
        rawFuelEntriesProvider(key.vehicleId).future,
      );
      final services = await ref.watch(
        serviceEntriesProvider(key.vehicleId).future,
      );
      final costs = await ref.watch(costEntriesProvider(key.vehicleId).future);
      final withReceipts = await ref.watch(
        entriesWithAttachmentsProvider.future,
      );
      return MissingReceipts.inMonth(
        entries: MoneyEntries.of(fuel: fuel, services: services, costs: costs),
        entryIdsWithAttachments: withReceipts,
        month: key.month,
      );
    });
