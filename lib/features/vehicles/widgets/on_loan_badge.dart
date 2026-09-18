import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_tokens.dart';
import '../providers/guest_pass_providers.dart';

/// "On loan until 3 Oct", on a car's card wherever the garage lists its cars.
///
/// Only the car's own page said a car was out, so from the dashboard and the
/// car list a car somebody else had looked like any other. The borrower's name
/// stays on that page; a card says only that it is out, and until when.
/// Nothing at all while the passes load, or when the car is home.
class OnLoanBadge extends ConsumerWidget {
  const OnLoanBadge({required this.vehicleId, required this.format, super.key});

  final String vehicleId;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passes = ref.watch(garagePassesProvider).value;
    final loan = passes == null
        ? null
        : liveLoanOn(passes, vehicleId, DateTime.now().toUtc());
    if (loan == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final colour = Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space1),
      child: Row(
        key: const Key('on-loan-badge'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_outlined, size: 16, color: colour),
          const SizedBox(width: GarageTokens.space1),
          Flexible(
            child: Text(
              l10n.vehicleOnLoanUntil(
                format.formatShortDate(loan.expiresAt.toLocal()),
              ),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
