import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../domain/entities/observation.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/observation_providers.dart';
import 'observation_sheet.dart';

/// What is wrong with this car and has not been sorted out.
///
/// Lives on the vehicle rather than in the timeline: the timeline is what
/// happened and what it cost, and a problem is a *state*. One that sat there
/// unchanged for four months would push four months of real entries down the
/// page while saying nothing new.
class ObservationsCard extends ConsumerWidget {
  const ObservationsCard({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final observations = ref.watch(observationsProvider(vehicleId)).value;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final now = DateTime.now().toUtc();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.observationsTitle.toUpperCase(),
                    style: GarageTheme.eyebrow(context),
                  ),
                ),
                TextButton.icon(
                  key: const Key('observation-add'),
                  onPressed: () =>
                      showObservationSheet(context, vehicleId: vehicleId),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.observationAdd),
                ),
              ],
            ),
            if (observations == null)
              const SizedBox.shrink()
            else if (observations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: GarageTokens.space2),
                child: Text(
                  l10n.observationsEmpty,
                  style: TextStyle(color: context.tokens.muted),
                ),
              )
            else
              for (final observation in observations)
                _ObservationRow(
                  observation: observation,
                  format: format,
                  now: now,
                ),
          ],
        ),
      ),
    );
  }
}

class _ObservationRow extends ConsumerWidget {
  const _ObservationRow({
    required this.observation,
    required this.format,
    required this.now,
  });

  final Observation observation;
  final UnitFormat format;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final (label, colour) = switch (observation.state) {
      ObservationState.open => (l10n.observationOpen, tokens.warn),
      // Its own colour, because "we did the work and it is still doing it" is
      // the line that matters most and the one a mechanic needs to see first.
      ObservationState.stillThere => (
        l10n.observationStillThere,
        tokens.danger,
      ),
      ObservationState.resolved => (l10n.observationResolved, tokens.muted),
    };

    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space3),
      child: Opacity(
        opacity: observation.isOpen ? 1 : 0.6,
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
                Expanded(
                  child: Text(
                    observation.isOpen
                        ? l10n.observationOpenFor(
                            observation.openForAt(now).inDays,
                          )
                        : l10n.observationResolvedOn(
                            format.formatDate(
                              observation.resolvedOn!.toLocal(),
                            ),
                          ),
                    style: TextStyle(color: tokens.muted),
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('observation-menu-${observation.id}'),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: observation.isOpen ? 'resolve' : 'reopen',
                      child: Text(
                        observation.isOpen
                            ? l10n.observationMarkResolved
                            : l10n.observationReopen,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.observationEdit),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.observationDelete),
                    ),
                  ],
                  onSelected: (value) => _act(context, ref, value),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: GarageTokens.space1),
              child: Text(observation.note),
            ),
            if (observation.state == ObservationState.stillThere)
              Padding(
                padding: const EdgeInsets.only(top: GarageTokens.space1),
                child: Text(
                  l10n.observationAddressedNotResolved,
                  style: TextStyle(color: tokens.danger),
                ),
              ),
            if (observation.odometerKm case final km?)
              Padding(
                padding: const EdgeInsets.only(top: GarageTokens.space1),
                child: Text(
                  format.formatDistance(km.toDouble(), decimals: 0),
                  style: GarageTheme.numeric(
                    Theme.of(context).textTheme.labelSmall!,
                  ).copyWith(color: tokens.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(observationControllerProvider.notifier);
    switch (action) {
      case 'resolve':
        await controller.resolve(observation, DateTime.now().toUtc());
      case 'reopen':
        await controller.reopen(observation);
      case 'edit':
        if (context.mounted) {
          await showObservationSheet(
            context,
            vehicleId: observation.vehicleId,
            existing: observation,
          );
        }
      case 'delete':
        if (!context.mounted) {
          return;
        }
        // The shared destructive prompt, worded for this row: deleting the
        // note deletes the record that anybody ever noticed the thing.
        final confirmed = await confirmDestructive(
          context,
          title: l10n.observationDelete,
          body: l10n.observationDeleteConfirm,
          confirmLabel: l10n.commonDelete,
        );
        if (confirmed) {
          await controller.delete(observation);
        }
    }
  }
}
