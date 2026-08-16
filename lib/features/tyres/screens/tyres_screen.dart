import '../../../core/widgets/dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/tyre_providers.dart';

String tyreSeasonLabel(AppLocalizations l10n, TyreSeason season) {
  return switch (season) {
    TyreSeason.summer => l10n.tyreSeasonSummer,
    TyreSeason.winter => l10n.tyreSeasonWinter,
    TyreSeason.allSeason => l10n.tyreSeasonAll,
  };
}

/// The tyre sets a vehicle runs on.
///
/// A set is its own thing: it moves on and off the car twice a year, wears on
/// its own schedule, and lives somewhere when it is off. Tracking it here — not
/// as a service entry — is what lets its tread be a series rather than a note.
class TyresScreen extends ConsumerStatefulWidget {
  const TyresScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<TyresScreen> createState() => _TyresScreenState();
}

class _TyresScreenState extends ConsumerState<TyresScreen> {
  AppFailure? _failure;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _failure = null);
    try {
      await action();
      ref.invalidate(tyreSetsProvider(widget.vehicleId));
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    }
  }

  Future<void> _addSet() async {
    final l10n = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final size = TextEditingController();
    final storage = TextEditingController();
    var season = TyreSeason.allSeason;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          actionsOverflowDirection: garageActionsOverflowDirection,
          actionsOverflowAlignment: garageActionsOverflowAlignment,
          title: Text(l10n.tyresAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledField(
                label: l10n.tyresName,
                child: TextField(controller: name, autofocus: true),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.tyresSeason,
                child: DropdownButtonFormField<TyreSeason>(
                  initialValue: season,
                  isExpanded: true,
                  items: [
                    for (final option in TyreSeason.values)
                      DropdownMenuItem(
                        value: option,
                        child: Text(tyreSeasonLabel(l10n, option)),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => season = value ?? season),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.tyresSize,
                child: TextField(controller: size),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.tyresStorage,
                child: TextField(controller: storage),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || name.text.trim().isEmpty) {
      return;
    }

    await _run(
      () => ref
          .read(tyreRepositoryProvider)
          .addSet(
            vehicleId: widget.vehicleId,
            name: name.text.trim(),
            season: season,
            size: size.text.trim().isEmpty ? null : size.text.trim(),
            storageLocation: storage.text.trim().isEmpty
                ? null
                : storage.text.trim(),
          ),
    );
  }

  Future<void> _recordTread(TyreSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final corners = {
      l10n.tyresFrontLeft: TextEditingController(),
      l10n.tyresFrontRight: TextEditingController(),
      l10n.tyresRearLeft: TextEditingController(),
      l10n.tyresRearRight: TextEditingController(),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
        title: Text(l10n.tyresAddReading),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final corner in corners.entries)
              LabeledField(
                label: '${corner.key} (mm)',
                child: TextField(
                  controller: corner.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    double? mm(String label) {
      final raw = corners[label]!.text.trim().replaceAll(',', '.');
      return raw.isEmpty ? null : double.tryParse(raw);
    }

    await _run(
      () => ref
          .read(tyreRepositoryProvider)
          .addReading(
            tyreSetId: set.id,
            date: DateTime.now(),
            frontLeftMm: mm(l10n.tyresFrontLeft),
            frontRightMm: mm(l10n.tyresFrontRight),
            rearLeftMm: mm(l10n.tyresRearLeft),
            rearRightMm: mm(l10n.tyresRearRight),
          ),
    );
  }

  Future<void> _retire(TyreSet set) async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    await _run(() => ref.read(tyreRepositoryProvider).retireSet(set.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final sets = ref.watch(tyreSetsProvider(widget.vehicleId));

    return GaragePageScaffold(
      title: l10n.tyresTitle,
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView<List<TyreSet>>(
              value: sets,
              onRetry: () => ref.invalidate(tyreSetsProvider(widget.vehicleId)),
              empty: () => EmptyState(message: l10n.tyresEmpty),
              data: (list) => ListView(
                padding: const EdgeInsets.all(GarageTokens.space4),
                children: [
                  for (final set in list)
                    _TyreSetCard(
                      set: set,
                      format: format,
                      onFit: () => _run(
                        () => ref
                            .read(tyreRepositoryProvider)
                            .fitSet(vehicleId: widget.vehicleId, setId: set.id),
                      ),
                      onRecordTread: () => _recordTread(set),
                      onRetire: () => _retire(set),
                    ),
                  if (_failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: GarageTokens.space3),
                      child: Text(
                        failureMessage(l10n, _failure!),
                        style: TextStyle(color: context.tokens.danger),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GarageTokens.space4),
            child: FilledButton.icon(
              onPressed: _addSet,
              icon: const Icon(Icons.add),
              label: Text(l10n.tyresAdd),
            ),
          ),
        ],
      ),
    );
  }
}

class _TyreSetCard extends StatelessWidget {
  const _TyreSetCard({
    required this.set,
    required this.format,
    required this.onFit,
    required this.onRecordTread,
    required this.onRetire,
  });

  final TyreSet set;
  final UnitFormat format;
  final VoidCallback onFit;
  final VoidCallback onRecordTread;
  final VoidCallback onRetire;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tread = set.latestReading?.shallowestMm;

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
                    set.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (set.isRetired)
                  Text(
                    l10n.tyresRetired,
                    style: TextStyle(color: context.tokens.muted),
                  )
                else if (set.fitted)
                  Text(
                    l10n.tyresFitted,
                    style: TextStyle(color: context.tokens.accent),
                  ),
              ],
            ),
            Text(
              [
                tyreSeasonLabel(l10n, set.season),
                if (set.size != null) set.size!,
                if (set.storageLocation != null) set.storageLocation!,
              ].join(' · '),
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space2),
            if (tread == null)
              Text(
                l10n.tyresTreadNone,
                style: TextStyle(color: context.tokens.muted),
              )
            else
              Text(
                '${l10n.tyresTread}: ${tread.toStringAsFixed(1)} mm',
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.bodyMedium!,
                ),
              ),
            if (set.isBelowLegalTread)
              Text(
                l10n.tyresBelowLegal,
                style: TextStyle(color: context.tokens.danger),
              ),
            Wrap(
              spacing: GarageTokens.space2,
              children: [
                if (!set.fitted && !set.isRetired)
                  TextButton(onPressed: onFit, child: Text(l10n.tyresFit)),
                TextButton(
                  onPressed: onRecordTread,
                  child: Text(l10n.tyresAddReading),
                ),
                if (!set.isRetired)
                  TextButton(
                    onPressed: onRetire,
                    child: Text(
                      l10n.tyresRetire,
                      style: TextStyle(color: context.tokens.danger),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
