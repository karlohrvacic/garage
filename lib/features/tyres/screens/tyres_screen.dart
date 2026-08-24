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
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../../core/clock.dart';
import '../../../domain/maintenance/tyre_age.dart';
import '../../../domain/maintenance/tyre_wear_projection.dart';
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

  /// Owned by the screen, not by the dialog that shows them.
  ///
  /// Created beside `showDialog` these were never disposed, so every open
  /// leaked one `ChangeNotifier` per field. Disposing them when the dialog's
  /// future completes is not the fix either: that future lands while the route
  /// is still animating out and the field still depends on the controller,
  /// which trips the framework's own assertion. Held here they are allocated
  /// once, cleared before each open, and disposed exactly when the screen is —
  /// the same ownership every entry sheet in this app already uses.
  final _setName = TextEditingController();
  final _setSize = TextEditingController();
  final _setStorage = TextEditingController();
  final _setDot = TextEditingController();
  final _tread = List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    _setName.dispose();
    _setSize.dispose();
    _setStorage.dispose();
    _setDot.dispose();
    for (final controller in _tread) {
      controller.dispose();
    }
    super.dispose();
  }

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

  /// Add and edit are the same form, the way every entry sheet in this app
  /// already works.
  ///
  /// A set used to be the one thing a household could create and not correct:
  /// a typo in the name, a wrong season, a moved storage box all meant deleting
  /// the set — and its whole tread history went with it, which is the one part
  /// that cannot be measured again after the fact.
  Future<void> _editSet([TyreSet? existing]) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _setName..text = existing?.name ?? '';
    final size = _setSize..text = existing?.size ?? '';
    final storage = _setStorage..text = existing?.storageLocation ?? '';
    // Shown back as the code that is on the tyre, not as the date it parses
    // to: the four digits are what somebody can check against the sidewall.
    final dot = _setDot..text = TyreDotCode.format(existing?.manufacturedOn);
    var season = existing?.season ?? TyreSeason.allSeason;
    String? dotError;

    final confirmed = await showAdaptiveEntrySheet<bool>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: existing == null ? l10n.tyresAdd : l10n.tyresEdit,
          fields: [
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
                    setSheetState(() => season = value ?? season),
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
            const SizedBox(height: GarageTokens.space3),
            LabeledField(
              label: l10n.tyresDotCode,
              child: TextField(
                key: const Key('tyre-dot-code'),
                controller: dot,
                keyboardType: TextInputType.number,
                style: GarageTheme.numericField(sheetContext),
                decoration: InputDecoration(
                  helperText: l10n.tyresDotCodeHint,
                  errorText: dotError,
                ),
                onChanged: (_) => setSheetState(() => dotError = null),
              ),
            ),
          ],
          confirmLabel: l10n.commonSave,
          onConfirm: () {
            // Refused rather than ignored: a code somebody typed and got wrong
            // is the one case where saving silently would lose the very thing
            // they went to the sidewall for.
            if (dot.text.trim().isNotEmpty &&
                TyreDotCode.parse(dot.text) == null) {
              setSheetState(() => dotError = l10n.tyresDotCodeInvalid);
              return;
            }
            Navigator.of(sheetContext).pop(true);
          },
          onCancel: () => Navigator.of(sheetContext).pop(false),
          cancelLabel: l10n.commonCancel,
        ),
      ),
    );
    if (confirmed != true || name.text.trim().isEmpty) {
      return;
    }

    final trimmedSize = size.text.trim();
    final trimmedStorage = storage.text.trim();
    final manufacturedOn = TyreDotCode.parse(dot.text);
    await _run(
      () => existing == null
          ? ref
                .read(tyreRepositoryProvider)
                .addSet(
                  vehicleId: widget.vehicleId,
                  name: name.text.trim(),
                  season: season,
                  size: trimmedSize.isEmpty ? null : trimmedSize,
                  storageLocation: trimmedStorage.isEmpty
                      ? null
                      : trimmedStorage,
                  manufacturedOn: manufacturedOn,
                )
          : ref
                .read(tyreRepositoryProvider)
                .updateSet(
                  setId: existing.id,
                  name: name.text.trim(),
                  season: season,
                  size: trimmedSize.isEmpty ? null : trimmedSize,
                  storageLocation: trimmedStorage.isEmpty
                      ? null
                      : trimmedStorage,
                  manufacturedOn: manufacturedOn,
                ),
    );
  }

  Future<void> _recordTread(TyreSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final corners = {
      l10n.tyresFrontLeft: _tread[0]..clear(),
      l10n.tyresFrontRight: _tread[1]..clear(),
      l10n.tyresRearLeft: _tread[2]..clear(),
      l10n.tyresRearRight: _tread[3]..clear(),
    };

    final confirmed = await showAdaptiveEntrySheet<bool>(
      context,
      (sheetContext) => EntrySheetBody(
        title: l10n.tyresAddReading,
        fields: [
          for (final corner in corners.entries)
            LabeledField(
              label: '${corner.key} (mm)',
              child: TextField(
                controller: corner.value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GarageTheme.numericField(sheetContext),
              ),
            ),
        ],
        confirmLabel: l10n.commonSave,
        onConfirm: () => Navigator.of(sheetContext).pop(true),
        onCancel: () => Navigator.of(sheetContext).pop(false),
        cancelLabel: l10n.commonCancel,
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

  /// Retiring is not deleting, and used to say it was.
  ///
  /// This reused `confirmDelete`, so taking a set off the car asked "Delete
  /// entry?" and warned that it could not be undone — of an action that keeps
  /// the set, keeps every reading on it, and only stops offering it to fit.
  Future<void> _retire(TyreSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.tyresRetireConfirmTitle,
      body: l10n.tyresRetireConfirmBody,
      confirmLabel: l10n.tyresRetire,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run(() => ref.read(tyreRepositoryProvider).retireSet(set.id));
  }

  /// The other half, which the repository could always do and nothing offered.
  ///
  /// Retiring is for a set that came off the car and still happened; deleting
  /// is for one entered by mistake, which should leave no trace. Only the
  /// second loses the readings, so only the second says so.
  Future<void> _delete(TyreSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.tyresDeleteConfirmTitle,
      body: l10n.tyresDeleteConfirmBody,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _run(() => ref.read(tyreRepositoryProvider).deleteSet(set.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final sets = ref.watch(tyreSetsProvider(widget.vehicleId));
    final today = ref.watch(todayProvider);
    final wear =
        ref.watch(tyreWearProjectionsProvider(widget.vehicleId)).value ??
        const {};

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
                      wear: wear[set.id],
                      age: TyreAge.assess(
                        manufacturedOn: set.manufacturedOn,
                        fittedAt: set.fittedAt,
                        today: today,
                      ),
                      onFit: () => _run(
                        () => ref
                            .read(tyreRepositoryProvider)
                            .fitSet(vehicleId: widget.vehicleId, setId: set.id),
                      ),
                      onEdit: () => _editSet(set),
                      onRecordTread: () => _recordTread(set),
                      onRetire: () => _retire(set),
                      onDelete: () => _delete(set),
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
              onPressed: _editSet,
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
    required this.wear,
    required this.age,
    required this.onFit,
    required this.onEdit,
    required this.onRecordTread,
    required this.onRetire,
    required this.onDelete,
  });

  final TyreSet set;
  final UnitFormat format;

  /// Estimated remaining life, or null when the set has not been measured
  /// twice — never shown as a reminder, only as a passive line under the
  /// tread reading.
  final TyreWearProjection? wear;

  /// How old the rubber is, or null when nothing dates the set. Independent of
  /// [wear]: a set can be legal on tread and years past it on age, and the two
  /// are separate reasons to replace it.
  final TyreAge? age;

  final VoidCallback onFit;
  final VoidCallback onEdit;
  final VoidCallback onRecordTread;
  final VoidCallback onRetire;
  final VoidCallback onDelete;

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
              )
            else if (wear != null)
              Text(
                // The distance is measured; the date is that distance over the
                // vehicle's driving rate, and a vehicle with no rate to measure
                // gets no date rather than one built on an assumption that
                // would read exactly like a measurement.
                switch (wear!.projectedReplacementDate) {
                  final date? => l10n.tyresWearEstimate(
                    format.formatDistance(wear!.remainingKm.toDouble()),
                    format.formatDate(date),
                  ),
                  null => l10n.tyresWearEstimateDistanceOnly(
                    format.formatDistance(wear!.remainingKm.toDouble()),
                  ),
                },
                style: TextStyle(color: context.tokens.muted),
              ),
            // Under the tread line, because age is the other half of the same
            // question and reads as a footnote to it. Nothing at all while the
            // set is fresh: a line that is always there stops being read.
            if (age case final it? when it.standing != TyreAgeStanding.fresh)
              Text(
                switch ((it.standing, it.estimated)) {
                  (TyreAgeStanding.expired, false) => l10n.tyresAgeExpired(
                    it.years,
                  ),
                  (TyreAgeStanding.expired, true) =>
                    l10n.tyresAgeExpiredEstimated(it.years),
                  (_, false) => l10n.tyresAgeAgeing(it.years),
                  (_, true) => l10n.tyresAgeAgeingEstimated(it.years),
                },
                style: TextStyle(
                  color: it.standing == TyreAgeStanding.expired
                      ? context.tokens.danger
                      : context.tokens.muted,
                ),
              ),
            Wrap(
              spacing: GarageTokens.space2,
              children: [
                if (!set.fitted && !set.isRetired)
                  TextButton(onPressed: onFit, child: Text(l10n.tyresFit)),
                TextButton(onPressed: onEdit, child: Text(l10n.commonEdit)),
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
                TextButton(
                  onPressed: onDelete,
                  child: Text(
                    l10n.tyresDelete,
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
