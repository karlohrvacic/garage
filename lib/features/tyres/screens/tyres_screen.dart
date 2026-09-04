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
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../core/clock.dart';
import '../../../domain/maintenance/tyre_age.dart';
import '../../../domain/maintenance/tyre_wear_projection.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
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

  /// Where the car stood when the tread was measured. Optional, and the only
  /// thing that turns a series of depths into a wear rate.
  final _treadOdometer = TextEditingController();

  @override
  void dispose() {
    _setName.dispose();
    _setSize.dispose();
    _setStorage.dispose();
    _setDot.dispose();
    for (final controller in _tread) {
      controller.dispose();
    }
    _treadOdometer.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? saidDone}) async {
    setState(() => _failure = null);
    try {
      await action();
      ref.invalidate(tyreSetsProvider(widget.vehicleId));
      // A tread reading changes one number on a card, and a correction that
      // reads the same as the figure it replaced looks like nothing
      // happened — which is how the same measurement got recorded three
      // times.
      if (saidDone != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(saidDone)));
      }
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
    // A motorcycle has a front and a rear of different sizes, not four
    // corners. Asking for four left a rider with two boxes to leave empty and
    // a form that plainly belonged to a car. The two readings are stored in
    // the front-left and rear-left columns: the table has no separate shape
    // for a bike, and every consumer of a reading takes the shallowest of
    // whatever is there.
    // Awaited rather than read off the cache: opened straight from a link the
    // vehicle may not have resolved yet, and a bike would then be asked for
    // four corners.
    Vehicle? vehicle;
    try {
      vehicle = await ref.read(vehicleProvider(widget.vehicleId).future);
    } catch (_) {
      // A car's form is the safe assumption; a tread reading is not worth
      // failing over a vehicle that cannot be read.
      vehicle = null;
    }
    if (!mounted) {
      return;
    }
    final twoWheeled = vehicle?.kind == 'motorcycle';
    final corners = twoWheeled
        ? {
            l10n.tyresFront: _tread[0]..clear(),
            l10n.tyresRear: _tread[2]..clear(),
          }
        : {
            l10n.tyresFrontLeft: _tread[0]..clear(),
            l10n.tyresFrontRight: _tread[1]..clear(),
            l10n.tyresRearLeft: _tread[2]..clear(),
            l10n.tyresRearRight: _tread[3]..clear(),
          };
    if (twoWheeled) {
      _tread[1].clear();
      _tread[3].clear();
    }

    _treadOdometer.clear();
    final prefs = ref.read(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    // Today by default, and editable: a reading is a dated measurement, and
    // two stamped the same day used to tie — the card then showed the first
    // of them for ever, so a corrected measurement vanished.
    var date = DateTime.now();

    final confirmed = await showAdaptiveEntrySheet<bool>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: l10n.tyresAddReading,
          fields: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.maintenanceServiceDate),
              subtitle: Text(format.formatShortDate(date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showGarageDatePicker(
                  context: sheetContext,
                  initialDate: date,
                  firstDate: firstLoggableDate(date),
                  lastDate: lastLoggableDate(date),
                );
                if (picked != null) {
                  setSheetState(() => date = picked);
                }
              },
            ),
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
            // Optional, and what the wear estimate is measured against: two
            // depths with no distance between them say nothing about a rate.
            LabeledField(
              label: l10n.fuelOdometer,
              child: TextField(
                controller: _treadOdometer,
                keyboardType: TextInputType.number,
                style: GarageTheme.numericField(sheetContext),
                decoration: InputDecoration(suffixText: format.distanceSuffix),
              ),
            ),
          ],
          confirmLabel: l10n.commonSave,
          onConfirm: () => Navigator.of(sheetContext).pop(true),
          onCancel: () => Navigator.of(sheetContext).pop(false),
          cancelLabel: l10n.commonCancel,
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }

    double? mm(String label) {
      final raw = corners[label]!.text.trim().replaceAll(',', '.');
      return raw.isEmpty ? null : double.tryParse(raw);
    }

    // Separators normalised like every other number field in the app: typed
    // as "124 000" or "124,000" this parsed to nothing and the reading saved
    // without the one field that turns a series of depths into a wear rate.
    final typed = _treadOdometer.text.trim().replaceAll(RegExp(r'[\s.,]'), '');
    final odometerDisplay = typed.isEmpty ? null : int.tryParse(typed);
    if (typed.isNotEmpty && odometerDisplay == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.amountNotANumber)));
      }
      return;
    }
    final odometerKm = odometerDisplay == null
        ? null
        : prefs.displayToKm(odometerDisplay.toDouble()).round();

    await _run(
      () => ref
          .read(tyreRepositoryProvider)
          .addReading(
            tyreSetId: set.id,
            date: date,
            odometerKm: odometerKm,
            frontLeftMm: mm(twoWheeled ? l10n.tyresFront : l10n.tyresFrontLeft),
            frontRightMm: twoWheeled ? null : mm(l10n.tyresFrontRight),
            rearLeftMm: mm(twoWheeled ? l10n.tyresRear : l10n.tyresRearLeft),
            rearRightMm: twoWheeled ? null : mm(l10n.tyresRearRight),
          ),
      saidDone: l10n.tyresReadingSaved,
    );
  }

  /// Retiring is not deleting, and used to say it was.
  ///
  /// This reused `confirmDelete`, so taking a set off the car asked "Delete
  /// entry?" and warned that it could not be undone — of an action that keeps
  /// the set, keeps every reading on it, and only stops offering it to fit.
  Future<void> _retire(TyreSet set) async {
    final l10n = AppLocalizations.of(context)!;
    // Not a deletion: the set and its readings stay. Red here taught people
    // to read red as "any confirmation", which is how a real deletion stops
    // registering.
    final confirmed = await confirmAction(
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

  Future<void> _unretire(TyreSet set) async {
    await _run(() => ref.read(tyreRepositoryProvider).unretireSet(set.id));
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
    // Both, together: the cards carry a legal claim that depends on what the
    // vehicle is, and rendering the car's 1.6 mm for a frame while the
    // vehicle loads is a flash of exactly the wrong figure on a motorcycle.
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    final sets = vehicle.isLoading
        ? const AsyncValue<List<TyreSet>>.loading()
        : ref.watch(tyreSetsProvider(widget.vehicleId));
    // A car when the vehicle cannot be read at all: three vehicles in four
    // are one, and a tread reading is not worth blocking over.
    final kind = vehicle.value?.kind ?? 'car';
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
                      legalMinimumMm: TyreSet.legalMinimumMmFor(kind),
                      twoWheeled: kind == 'motorcycle',
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
                      onUnretire: () => _unretire(set),
                      onUnfit: () => _run(
                        () => ref.read(tyreRepositoryProvider).unfitSet(set.id),
                      ),
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
    required this.legalMinimumMm,
    required this.twoWheeled,
    required this.wear,
    required this.age,
    required this.onFit,
    required this.onEdit,
    required this.onRecordTread,
    required this.onRetire,
    required this.onUnretire,
    required this.onUnfit,
    required this.onDelete,
  });

  final TyreSet set;
  final UnitFormat format;

  /// What the law asks of *this* vehicle: 1.0 mm on a motorcycle, 1.6 on a
  /// car. Printing the car figure on a bike is a legal claim that is not
  /// true of it.
  final double legalMinimumMm;

  /// A motorcycle, whose two readings are stored as the left of each axle and
  /// are named front and rear rather than by corner.
  final bool twoWheeled;

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
  final VoidCallback onUnretire;
  final VoidCallback onUnfit;
  final VoidCallback onDelete;

  /// " (rear left)", or nothing when only one figure was taken — on a bike,
  /// where a single number is unambiguous, or on a set measured once. The
  /// depth says the set needs replacing; the position says whether that is
  /// wear or a fault.
  String? _corner(AppLocalizations l10n, TyreCorner? corner) {
    if (corner == null || (set.latestReading?.spreadMm == null)) {
      return null;
    }
    final label = switch ((corner, twoWheeled)) {
      (TyreCorner.frontLeft, true) => l10n.tyresFront,
      (TyreCorner.rearLeft, true) => l10n.tyresRear,
      (TyreCorner.frontLeft, false) => l10n.tyresFrontLeft,
      (TyreCorner.frontRight, _) => l10n.tyresFrontRight,
      (TyreCorner.rearLeft, false) => l10n.tyresRearLeft,
      (TyreCorner.rearRight, _) => l10n.tyresRearRight,
    };
    return ' (${label.toLowerCase()})';
  }

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
                // Only while it is off the car. A set on the vehicle that
                // also says "Garage shelf" is two answers to one question.
                if (!set.fitted && set.storageLocation != null)
                  set.storageLocation!,
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
                '${l10n.tyresTread}: ${format.formatMillimetres(tread)}'
                '${_corner(l10n, set.latestReading?.shallowestCorner) ?? ''}',
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.bodyMedium!,
                ),
              ),
            // When it was taken. Two readings a week apart are a wear rate;
            // one from last winter is a number to check again.
            if (set.latestReading case final reading? when tread != null)
              Text(
                l10n.tyresMeasuredOn(format.formatShortDate(reading.date)),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
            // Left against right on one axle: a gap there is alignment or
            // suspension, a different problem from a set wearing out, and the
            // worst corner alone cannot tell them apart. Front against rear
            // is not a fault — every bike wears its rear out first, and so
            // does a front-wheel-drive car's front — so it is not measured
            // here. Past a millimetre only: a hand-held depth gauge does not
            // resolve tenths.
            if (set.latestReading?.worstAxle case final axle?
                when axle.high - axle.low >= 1)
              Text(
                l10n.tyresUneven(
                  format.formatMillimetres(axle.low),
                  format.formatMillimetres(axle.high),
                ),
                style: TextStyle(color: context.tokens.muted),
              ),
            if (set.isBelowLegal(legalMinimumMm))
              Text(
                l10n.tyresBelowLegalAt(
                  format.formatMillimetres(legalMinimumMm),
                ),
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
                if (!set.isRetired)
                  TextButton(
                    onPressed: onRecordTread,
                    child: Text(l10n.tyresAddReading),
                  ),
                // Behind a menu: two red words wrapping to a second line,
                // weighted the same as "Fit to vehicle", is not where a
                // destructive action belongs.
                PopupMenuButton<void>(
                  tooltip: l10n.tyresMoreActions,
                  itemBuilder: (context) => [
                    // Fitting another set already swaps them; a household
                    // with one set had no way to say the car is on something
                    // else, and its storage line went on claiming a shelf.
                    if (set.fitted && !set.isRetired)
                      PopupMenuItem<void>(
                        onTap: onUnfit,
                        child: Text(l10n.tyresUnfit),
                      ),
                    if (set.isRetired)
                      PopupMenuItem<void>(
                        onTap: onUnretire,
                        child: Text(l10n.tyresUnretire),
                      )
                    else
                      PopupMenuItem<void>(
                        // Not red: the set and its readings stay.
                        onTap: onRetire,
                        child: Text(l10n.tyresRetire),
                      ),
                    PopupMenuItem<void>(
                      onTap: onDelete,
                      child: Text(
                        l10n.tyresDelete,
                        style: TextStyle(color: context.tokens.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
