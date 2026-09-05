import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/entities/guest_pass.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/guest_pass_providers.dart';
import '../providers/vehicle_providers.dart';
import '../widgets/lend_car_sheet.dart';

/// Who this car has been lent to, and to whom it is out right now.
class GuestPassesScreen extends ConsumerWidget {
  const GuestPassesScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final passes = ref.watch(vehicleGuestPassesProvider(vehicleId));
    final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
    final now = DateTime.now().toUtc();
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return GaragePageScaffold(
      title: vehicle?.nickname ?? l10n.guestPassesTitle,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('lend-car'),
        onPressed: () => showLendCarSheet(context, ref, vehicleId),
        icon: const Icon(Icons.key_outlined),
        label: Text(l10n.guestLendTitle),
      ),
      body: AsyncValueView<List<GuestPass>>(
        value: passes,
        onRetry: () => ref.invalidate(vehicleGuestPassesProvider(vehicleId)),
        empty: () => EmptyState(message: l10n.guestPassesEmpty),
        data: (list) {
          final ordered = GuestPasses.forDisplay(list, now);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              GarageTokens.space4,
              GarageTokens.space4,
              GarageTokens.space4,
              GarageTokens.fabClearance,
            ),
            itemCount: ordered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: GarageTokens.space4),
                  child: Text(
                    l10n.guestLendIntro,
                    style: TextStyle(color: context.tokens.muted),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                child: _PassRow(
                  pass: ordered[index - 1],
                  now: now,
                  format: format,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PassRow extends ConsumerWidget {
  const _PassRow({required this.pass, required this.now, required this.format});

  final GuestPass pass;
  final DateTime now;
  final UnitFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final state = pass.stateAt(now);
    final (label, colour) = switch (state) {
      GuestPassState.live => (l10n.guestPassesLive, tokens.success),
      GuestPassState.waiting => (l10n.guestPassesWaiting, tokens.warn),
      GuestPassState.notStarted => (l10n.guestPassesNotStarted, tokens.muted),
      GuestPassState.expired => (l10n.guestPassesExpired, tokens.muted),
      GuestPassState.revoked => (l10n.guestPassesRevoked, tokens.muted),
    };
    final days = pass.remainingAt(now).inDays;
    final open =
        state == GuestPassState.live ||
        state == GuestPassState.waiting ||
        state == GuestPassState.notStarted;

    return Container(
      padding: const EdgeInsets.all(GarageTokens.space4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GarageTokens.space2,
                        vertical: GarageTokens.space1,
                      ),
                      decoration: BoxDecoration(
                        color: colour.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          GarageTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colour,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: GarageTokens.space3),
                    Text(
                      pass.code,
                      style: GarageTheme.numeric(
                        Theme.of(context).textTheme.bodyMedium!,
                      ),
                    ),
                  ],
                ),
                if (pass.label case final name?) ...[
                  const SizedBox(height: GarageTokens.space2),
                  Text(name),
                ],
                const SizedBox(height: GarageTokens.space1),
                Text(
                  open
                      ? (days == 0
                            ? l10n.guestPassEndsToday
                            : l10n.guestPassRemaining(days))
                      : format.formatDate(pass.expiresAt.toLocal()),
                  style: TextStyle(color: tokens.muted),
                ),
              ],
            ),
          ),
          if (open)
            TextButton(
              onPressed: () => _confirmRevoke(context, ref, pass),
              child: Text(l10n.guestPassRevoke),
            ),
        ],
      ),
    );
  }
}

Future<void> _confirmRevoke(
  BuildContext context,
  WidgetRef ref,
  GuestPass pass,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.guestPassRevokeConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.guestPassRevoke),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(guestPassControllerProvider.notifier).revoke(pass);
  }
}
