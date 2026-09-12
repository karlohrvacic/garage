import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/sync/pending_write.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../settings/providers/unit_providers.dart';

/// What is still on the phone, and a way to ask again now.
class PendingSyncScreen extends ConsumerWidget {
  const PendingSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pending = ref.watch(pendingWritesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return GaragePageScaffold(
      title: l10n.syncPendingTitle,
      body: AsyncValueView<List<PendingWrite>>(
        value: pending,
        onRetry: () => ref.invalidate(pendingWritesProvider),
        empty: () => EmptyState(message: l10n.syncPendingEmpty),
        data: (writes) => ListView(
          padding: const EdgeInsets.all(GarageTokens.space4),
          children: [
            Text(
              l10n.syncPendingIntro,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space5),
            for (final write in writes)
              Card(
                child: ListTile(
                  key: Key('pending-${write.id}'),
                  leading: Icon(switch (write.kind) {
                    PendingWriteKind.fuel => Icons.local_gas_station_outlined,
                    PendingWriteKind.odometer => Icons.speed_outlined,
                    PendingWriteKind.attachment => Icons.photo_outlined,
                    PendingWriteKind.trip => Icons.route_outlined,
                    PendingWriteKind.cost => Icons.receipt_long_outlined,
                    PendingWriteKind.service => Icons.build_outlined,
                    PendingWriteKind.observation =>
                      Icons.report_problem_outlined,
                  }),
                  title: Text(switch (write.kind) {
                    PendingWriteKind.fuel => l10n.syncKindFuel,
                    PendingWriteKind.odometer => l10n.syncKindOdometer,
                    PendingWriteKind.attachment => l10n.syncKindAttachment,
                    PendingWriteKind.trip => l10n.syncKindTrip,
                    PendingWriteKind.cost => l10n.syncKindCost,
                    PendingWriteKind.service => l10n.syncKindService,
                    PendingWriteKind.observation => l10n.syncKindObservation,
                  }),
                  subtitle: Text(
                    l10n.syncQueuedAt(
                      format.formatDate(write.queuedAt.toLocal()),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: GarageTokens.space5),
            FilledButton.icon(
              key: const Key('sync-retry'),
              onPressed: () => _retry(context, ref),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.syncRetryNow),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _retry(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  final report = await ref.read(syncControllerProvider.notifier).run();

  // Every outcome says something. A retry that reports nothing reads as a
  // button that does nothing.
  if (report.discarded > 0) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.syncDiscarded(report.discarded))),
    );
  }
  if (report.sent > 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.syncSent(report.sent))));
  } else if (report.discarded == 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.syncStillWaiting)));
  }
}
