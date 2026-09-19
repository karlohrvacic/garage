import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/clock.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/company/money_entry.dart';
import '../../costs/providers/cost_providers.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../fuel/widgets/fuel_entry_sheet.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/company_providers.dart';
import '../providers/receipt_providers.dart';
import 'missing_receipt_row.dart';
import 'paid_with_field.dart';

/// This month's entries on this car with no receipt, and the one action
/// that fixes each: the sheet, where the paperclip is.
///
/// Nothing at all off the plan, and nothing when the month is clean: a card
/// saying "none missing" would sit on every private car's Costs tab for a
/// rule that does not apply there.
class MissingReceiptsCard extends ConsumerWidget {
  const MissingReceiptsCard({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(companyPlanProvider)) {
      return const SizedBox.shrink();
    }
    final today = ref.watch(todayProvider);
    final month = DateTime.utc(today.year, today.month);
    // This car's own lists, which the tabs around the card read anyway; a
    // read that failed is said by the list under the card, not twice.
    final missing =
        ref
            .watch(
              vehicleMissingReceiptsProvider((
                vehicleId: vehicleId,
                month: month,
              )),
            )
            .value ??
        const <MoneyEntry>[];
    if (missing.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    return Padding(
      // The same inset as the running-cost card under it, carried here so
      // that a tab with nothing to show has no gap where the card would be.
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space2,
        GarageTokens.space4,
        0,
      ),
      child: Card(
        key: const Key('missing-receipts'),
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.companyMissingReceipts.toUpperCase(),
                style: GarageTheme.eyebrow(context),
              ),
              for (final entry in missing)
                MissingReceiptRow(
                  title:
                      '${moneyEntryKindLabel(l10n, entry.kind)} · '
                      '${format.formatDate(entry.date)}',
                  amount: format.formatMoney(entry.amount),
                  actionLabel: l10n.companyPhotoNow,
                  actionKey: Key('photo-now-${entry.id}'),
                  onAction: () => _open(context, ref, entry),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The entry's own sheet, which is where a receipt is attached. The list
  /// is read rather than watched: a tap wants the row as it is now, and an
  /// entry deleted since the card was drawn is simply not opened.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    MoneyEntry entry,
  ) async {
    switch (entry.kind) {
      case MoneyEntryKind.fuel:
        final fills = await ref.read(rawFuelEntriesProvider(vehicleId).future);
        final fill = fills.where((it) => it.id == entry.id).firstOrNull;
        if (fill != null && context.mounted) {
          await showFuelEntrySheet(context, vehicleId, existing: fill);
        }
      case MoneyEntryKind.service:
        final services = await ref.read(
          serviceEntriesProvider(vehicleId).future,
        );
        final service = services.where((it) => it.id == entry.id).firstOrNull;
        if (service != null && context.mounted) {
          await showServiceEntrySheet(context, vehicleId, existing: service);
        }
      case MoneyEntryKind.cost:
        final costs = await ref.read(costEntriesProvider(vehicleId).future);
        final cost = costs.where((it) => it.id == entry.id).firstOrNull;
        if (cost != null && context.mounted) {
          await showCostEntrySheet(context, vehicleId, existing: cost);
        }
    }
  }
}
