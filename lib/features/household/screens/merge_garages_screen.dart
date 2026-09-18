import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/entities/household.dart';
import '../data/merge_action.dart';
import '../providers/household_providers.dart';
import '../../../core/widgets/confirm_delete.dart';

/// Two garages becoming one.
///
/// The surviving garage is the one you are in; you pick the one to dissolve.
/// Irreversible, so the confirmation names what moves rather than asking a
/// bare "are you sure".
class MergeGaragesScreen extends ConsumerWidget {
  const MergeGaragesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final surviving = ref.watch(currentHouseholdProvider).value;
    final mine = ref.watch(myHouseholdsProvider);

    return GaragePageScaffold(
      title: l10n.householdMergeTitle,
      body: AsyncValueView<List<Household>>(
        value: mine,
        onRetry: () => ref.invalidate(garageBootstrapProvider),
        data: (households) {
          // Only garages you are an admin of can be dissolved, and never the
          // one you are standing in.
          final candidates = [
            for (final household in households)
              if (household.id != surviving?.id) household,
          ];
          return ListView(
            padding: const EdgeInsets.all(GarageTokens.space4),
            children: [
              Text(
                l10n.householdMergeIntro,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space3),
              Text(
                l10n.householdMergeKeysWarning,
                style: TextStyle(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space6),
              if (candidates.isEmpty)
                Text(l10n.householdMergeNone)
              else ...[
                Text(
                  l10n.householdMergePick.toUpperCase(),
                  style: GarageTheme.eyebrow(context),
                ),
                const SizedBox(height: GarageTokens.space2),
                for (final candidate in candidates)
                  Card(
                    child: ListTile(
                      key: Key('merge-${candidate.id}'),
                      leading: const Icon(Icons.merge_outlined),
                      title: Text(candidate.name),
                      subtitle: Text(candidate.currencyCode),
                      onTap: surviving == null
                          ? null
                          : () => _confirm(context, ref, candidate, surviving),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

Future<void> _confirm(
  BuildContext context,
  WidgetRef ref,
  Household absorbed,
  Household surviving,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  // Checked before the confirmation rather than after it: being told what is
  // about to happen and then refused is worse than being told why it cannot.
  if (absorbed.currencyCode != surviving.currencyCode) {
    await showNotice(
      context,
      content: Text(
        l10n.householdMergeCurrencyClash(
          absorbed.currencyCode,
          surviving.currencyCode,
        ),
      ),
    );
    return;
  }

  final counts = await ref.read(mergePreviewProvider(absorbed.id).future);
  if (!context.mounted) {
    return;
  }

  // Red: the garage merged away is gone, and nothing splits it out again.
  final confirmed = await confirmDestructive(
    context,
    body: l10n.householdMergeConfirm(
      absorbed.name,
      surviving.name,
      l10n.householdMergeVehicleCount(counts.vehicles),
      l10n.householdMergePeopleCount(counts.people),
    ),
    confirmLabel: l10n.householdMergeAction,
  );
  if (!confirmed) {
    return;
  }

  try {
    final outcome = await ref
        .read(householdControllerProvider.notifier)
        .mergeInto(absorbed: absorbed, surviving: surviving);
    if (outcome == null) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.householdMergeDone(
            l10n.householdMergeVehicleCount(outcome.vehiclesMoved),
          ),
        ),
      ),
    );
    if (outcome.photosLost > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.householdMergePhotosLost(outcome.photosLost)),
        ),
      );
    }
    router.go('/household');
  } on MergeCurrencyMismatch catch (mismatch) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.householdMergeCurrencyClash(
            mismatch.absorbed,
            mismatch.surviving,
          ),
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
  }
}
