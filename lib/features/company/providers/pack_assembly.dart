import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../domain/company/money_entry.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/cost_entry.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/entities/household.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/entities/vehicle.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../household/providers/member_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../reports/accountant_pack.dart';
import '../../reports/report_builder.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import 'company_providers.dart';

/// What the tab shows while the receipts come down: [done] of [total].
typedef PackProgress = void Function(int done, int total);

final accountantPackAssemblyProvider = Provider<AccountantPackAssembly>((ref) {
  return AccountantPackAssembly(ref);
});

/// Gathers a month across the fleet and hands it to the pack builder: every
/// car's rows, every receipt's bytes, the log and the names. Kept out of
/// the tab so the fetching can be tested without pumping the console, and
/// so the tab is left with what it is for, the button and the progress.
class AccountantPackAssembly {
  AccountantPackAssembly(this._ref);

  final Ref _ref;

  /// The month's zip, ready to save. Nothing is handed back until every
  /// byte is in hand: a download that fails throws, and no half-built pack
  /// reaches the accountant.
  Future<Uint8List> build({
    required DateTime month,
    required String locale,
    required AppLocalizations l10n,
    required UnitFormat format,
    PackProgress? onProgress,
  }) async {
    final household = await _ref.read(currentHouseholdProvider.future);
    // Archived cars too: a car sold on the tenth has that month's entries
    // and the accountant wants them beside the rest.
    final vehicles = await _ref.read(allVehiclesProvider.future);
    final assignments = await _ref.read(fleetAssignmentsProvider.future);
    final names = await _ref.read(memberNamesProvider.future);
    final withReceipts = await _ref.read(entriesWithAttachmentsProvider.future);
    final attachments = _ref.read(attachmentRepositoryProvider);
    final period = ReportPeriod(
      from: month,
      to: DateTime.utc(month.year, month.month + 1, 0),
      label: DateFormat.yMMMM(locale).format(month),
    );

    // Every car's month first, and which of its entries have a receipt to
    // fetch, so the count is known before the first download.
    final months = <_CarMonth>[];
    for (final vehicle in vehicles) {
      final fuel = await _ref.read(rawFuelEntriesProvider(vehicle.id).future);
      final services = await _ref.read(
        serviceEntriesProvider(vehicle.id).future,
      );
      final costs = await _ref.read(costEntriesProvider(vehicle.id).future);
      // Money entries only: a fill-up with no total has no ledger row and
      // nothing a receipt could be for.
      final entries = MoneyEntries.of(
        fuel: fuel.where((e) => period.contains(e.date)),
        services: services.where((e) => period.contains(e.date)),
        costs: costs.where((e) => period.contains(e.date)),
      );
      // A car sold before the month has nothing in it and gets no folder:
      // one empty folder per car ever owned, every month, is noise.
      if (vehicle.archived && entries.isEmpty) {
        continue;
      }
      months.add(
        _CarMonth(
          vehicle: vehicle,
          fuel: fuel,
          services: services,
          costs: costs,
          withReceipts: [
            for (final entry in entries)
              if (withReceipts.contains(entry.id)) entry,
          ],
        ),
      );
    }

    // The receipts listed before any is downloaded, so the progress line
    // can say "of m" from the first one.
    final pending = <(int, Attachment)>[];
    for (final (index, car) in months.indexed) {
      for (final entry in car.withReceipts) {
        final listed = await attachments.forEntry(
          kind: AttachmentEntryKind.fromKey(entry.kind.key),
          entryId: entry.id,
        );
        for (final attachment in listed) {
          pending.add((index, attachment));
        }
      }
    }
    final receipts = [for (final _ in months) <ReceiptImage>[]];
    var done = 0;
    onProgress?.call(done, pending.length);
    for (final (index, attachment) in pending) {
      receipts[index].add(
        ReceiptImage(
          attachment: attachment,
          bytes: await attachments.download(attachment),
        ),
      );
      onProgress?.call(++done, pending.length);
    }

    return buildAccountantPack(
      cars: [
        for (final (index, car) in months.indexed)
          VehiclePack(
            vehicle: car.vehicle,
            fuel: car.fuel,
            services: car.services,
            costs: car.costs,
            receipts: receipts[index],
            assignments: assignments,
            driverNames: names,
          ),
      ],
      period: period,
      letterhead: letterheadOf(household),
      l10n: l10n,
      format: format,
    );
  }
}

/// What the ledger prints above the table: the company's name and OIB, or
/// nothing for a garage that has set neither.
String? letterheadOf(Household? household) {
  final letterhead = [
    ?household?.companyName,
    ?household?.companyOib,
  ].join(' · ');
  return letterhead.isEmpty ? null : letterhead;
}

/// One car's rows, and the month's entries that have something attached.
class _CarMonth {
  const _CarMonth({
    required this.vehicle,
    required this.fuel,
    required this.services,
    required this.costs,
    required this.withReceipts,
  });

  final Vehicle vehicle;
  final List<FuelEntry> fuel;
  final List<ServiceEntry> services;
  final List<CostEntry> costs;
  final List<MoneyEntry> withReceipts;
}
