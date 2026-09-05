import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';

/// Says that something typed without a signal is still on the phone.
///
/// Shown wherever a person would look for the entry they just made, because
/// the alternative is an entry that is safe and looks lost — which is the same
/// thing as lost, to the person holding the phone.
class PendingSyncBanner extends ConsumerWidget {
  const PendingSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final pending = ref.watch(pendingWritesProvider).value ?? const [];
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: GarageTokens.space3),
      child: Material(
        color: tokens.warn.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
        child: InkWell(
          key: const Key('pending-sync-banner'),
          borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
          onTap: () => context.push('/pending'),
          child: Padding(
            padding: const EdgeInsets.all(GarageTokens.space4),
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: tokens.warn),
                const SizedBox(width: GarageTokens.space3),
                Expanded(child: Text(l10n.syncPendingBanner(pending.length))),
                Icon(Icons.chevron_right, color: tokens.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
