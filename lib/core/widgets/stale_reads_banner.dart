import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../sync/invalidate_reads.dart';
import '../sync/read_cache_providers.dart';
import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// One line at the top of every screen while any list on it is a copy.
///
/// A list served from the cache looks exactly like a fresh one, which is the
/// point of serving it and the danger of it. The line says when the copy was
/// taken — the oldest of them, since a screen is only as current as its least
/// current list — and offers to try the server again.
class StaleReadsBanner extends ConsumerWidget {
  const StaleReadsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stale = ref.watch(staleReadsProvider);
    return ValueListenableBuilder(
      valueListenable: stale,
      builder: (context, reads, _) {
        final oldest = reads.oldest;
        if (oldest == null) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context)!;
        final tokens = context.tokens;
        final when = DateFormat.MMMEd(
          l10n.localeName,
        ).add_Hm().format(oldest.toLocal());
        return Material(
          color: tokens.surface,
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: GarageTokens.space4,
              vertical: GarageTokens.space2,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Icon(Icons.cloud_off_outlined, size: 18, color: tokens.muted),
                  const SizedBox(width: GarageTokens.space2),
                  Expanded(
                    child: Text(
                      l10n.syncStaleBanner(when),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                  ),
                  // A row hands its button all the width it asks for, and
                  // "Pokušaj ponovno" at 1.5x asks for more than a 320px
                  // phone has. Held to half the strip, the label wraps inside
                  // the button and the message keeps the other half.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: TextButton(
                      onPressed: () => invalidateReadsFromWidget(ref),
                      child: Text(l10n.commonRetry),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
