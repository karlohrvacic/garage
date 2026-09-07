import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/entities/service_entry.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/guest_pass_providers.dart';
import '../providers/vehicle_providers.dart';

/// What was done to a car somebody lent you.
///
/// The borrower's own screens show only what they logged themselves, which is
/// the right default and useless to a mechanic: the question they are holding
/// the car to answer is what has already been done to it. A pass can open
/// this, and can open it without the prices — those are two decisions, and an
/// owner is entitled to make them separately.
///
/// The masking is the database's. `guest_service_history` returns a null cost
/// when the pass does not carry prices, so what is not shown here is also not
/// in the response.
class LentHistoryScreen extends ConsumerWidget {
  const LentHistoryScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.watch(lentServiceHistoryProvider(vehicleId));
    final pass = ref.watch(guestPassForVehicleProvider(vehicleId));
    final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    // Null for the owner, who is not a guest and sees every figure anyway.
    final pricesHidden = pass != null && !pass.canViewPrices;

    return GaragePageScaffold(
      title: vehicle?.nickname ?? l10n.lentHistoryTitle,
      body: AsyncValueView<List<ServiceEntry>>(
        value: history,
        onRetry: () => ref.invalidate(lentServiceHistoryProvider(vehicleId)),
        empty: () => EmptyState(message: l10n.lentHistoryEmpty),
        data: (entries) {
          return ListView.builder(
            padding: const EdgeInsets.all(GarageTokens.space4),
            itemCount: entries.length + (pricesHidden ? 1 : 0),
            itemBuilder: (context, index) {
              if (pricesHidden && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: GarageTokens.space4),
                  child: Text(
                    l10n.lentHistoryPricesHidden,
                    style: TextStyle(color: context.tokens.muted),
                  ),
                );
              }
              final entry = entries[index - (pricesHidden ? 1 : 0)];
              return _HistoryRow(entry: entry, format: format);
            },
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.format});

  final ServiceEntry entry;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final what = entry.serviceTypeKeys
        .map((key) => serviceTypeLabel(l10n, key))
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Container(
        padding: const EdgeInsets.all(GarageTokens.space4),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    what,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                // Absent when the pass hides it, and absent when nobody
                // recorded one. The line above the list says which.
                if (entry.cost case final cost?) ...[
                  const SizedBox(width: GarageTokens.space3),
                  Text(format.formatMoney(cost)),
                ],
              ],
            ),
            const SizedBox(height: GarageTokens.space1),
            Text(
              '${format.formatDate(entry.date.toLocal())} · '
              '${format.formatDistance(entry.odometerKm.toDouble(), decimals: 0)}',
              style: TextStyle(color: tokens.muted),
            ),
            if (entry.shop case final shop? when shop.isNotEmpty) ...[
              const SizedBox(height: GarageTokens.space1),
              Text(shop, style: TextStyle(color: tokens.muted)),
            ],
            if (entry.notes case final notes? when notes.isNotEmpty) ...[
              const SizedBox(height: GarageTokens.space2),
              Text(notes),
            ],
          ],
        ),
      ),
    );
  }
}
