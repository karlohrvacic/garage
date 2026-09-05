import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/trip_draft.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/trip_providers.dart';

/// Opening a drive and closing it again, on whichever screen shows a vehicle's
/// journeys.
///
/// Two taps around a journey — one when you set off, one when you park —
/// instead of remembering an hour later what the odometer said. The clock is
/// read for you; the odometer is the single number visible from the driver's
/// seat.
class DriveCard extends ConsumerWidget {
  const DriveCard({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(openTripDraftProvider(vehicleId));

    // Nothing at all while the answer is unknown. A "Start a drive" button
    // that turns into an in-progress card a moment later would invite a tap
    // that opens a second drive on a car already out.
    return switch (draft) {
      AsyncData(:final value?) => _InProgress(draft: value),
      AsyncData() => _StartButton(vehicleId: vehicleId),
      _ => const SizedBox.shrink(),
    };
  }
}

class _StartButton extends ConsumerWidget {
  const _StartButton({required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      key: const Key('drive-start'),
      onPressed: () => showStartDriveSheet(context, ref, vehicleId),
      icon: const Icon(Icons.play_arrow_outlined),
      label: Text(l10n.tripDriveStart),
    );
  }
}

class _InProgress extends ConsumerWidget {
  const _InProgress({required this.draft});

  final TripDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final locale = Localizations.localeOf(context).languageCode;
    final elapsed = draft.elapsedAt(DateTime.now().toUtc());

    return Container(
      key: const Key('drive-in-progress'),
      padding: const EdgeInsets.all(GarageTokens.space4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
        // The one place a drive announces itself. It is the only thing on the
        // screen that is still happening.
        border: Border.all(color: tokens.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tripDriveInProgress.toUpperCase(),
            style: GarageTheme.eyebrow(context).copyWith(color: tokens.accent),
          ),
          const SizedBox(height: GarageTokens.space2),
          Text(
            l10n.tripDriveSince(
              DateFormat.Hm(locale).format(draft.startedAt.toLocal()),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            l10n.tripDriveElapsed(_elapsedLabel(elapsed)),
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.titleMedium!,
            ).copyWith(color: tokens.fg),
          ),
          const SizedBox(height: GarageTokens.space4),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('drive-finish'),
                  onPressed: () => showFinishDriveSheet(context, ref, draft),
                  child: Text(l10n.tripDriveFinish),
                ),
              ),
              const SizedBox(width: GarageTokens.space3),
              TextButton(
                key: const Key('drive-discard'),
                onPressed: () => _confirmDiscard(context, ref, draft),
                child: Text(l10n.tripDriveDiscard),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "1 h 05 min" rather than a bare minute count: an hour and five minutes
/// read as "65 min" is arithmetic the driver has to do.
String _elapsedLabel(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes % 60;
  if (hours == 0) {
    return '$minutes min';
  }
  return '$hours h ${minutes.toString().padLeft(2, '0')} min';
}

Future<void> _confirmDiscard(
  BuildContext context,
  WidgetRef ref,
  TripDraft draft,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(l10n.tripDriveDiscardConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.tripDriveDiscard),
        ),
      ],
    ),
  );
  if (confirmed != true) {
    return;
  }
  final ok = await ref
      .read(tripDraftControllerProvider.notifier)
      .discard(draft);
  if (!ok) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
  }
}

Future<void> showStartDriveSheet(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await showAdaptiveEntrySheet<void>(context, (sheetContext) {
    return _StartDriveForm(vehicleId: vehicleId, messenger: messenger);
  });
}

/// Owns its controller.
///
/// Disposing one from the calling function looks equivalent and is not: the
/// sheet is still animating out when `showAdaptiveEntrySheet` returns, and the
/// field it belongs to gets built again on the way, against a controller that
/// no longer exists.
class _StartDriveForm extends ConsumerStatefulWidget {
  const _StartDriveForm({required this.vehicleId, required this.messenger});

  final String vehicleId;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_StartDriveForm> createState() => _StartDriveFormState();
}

class _StartDriveFormState extends ConsumerState<_StartDriveForm> {
  final _odometer = TextEditingController();

  @override
  void dispose() {
    _odometer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EntrySheetBody(
      title: l10n.tripDriveStart,
      fields: [
        LabeledField(
          label: l10n.tripDriveOdometerNow,
          child: TextField(
            key: const Key('drive-start-odometer'),
            controller: _odometer,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: GarageTheme.numericField(context),
            decoration: InputDecoration(
              hintText: l10n.tripDriveOdometerNowHint,
            ),
          ),
        ),
      ],
      confirmLabel: l10n.tripDriveStart,
      onConfirm: _start,
    );
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final ok = await ref
        .read(tripDraftControllerProvider.notifier)
        .start(
          vehicleId: widget.vehicleId,
          // Stamped here, not in the repository: this is the moment the
          // person said they were setting off.
          startedAt: DateTime.now().toUtc(),
          startOdometerKm: int.tryParse(_odometer.text.trim()),
        );
    navigator.pop();
    widget.messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.tripDriveStarted : l10n.tripDriveAlreadyOpen),
      ),
    );
  }
}

Future<void> showFinishDriveSheet(
  BuildContext context,
  WidgetRef ref,
  TripDraft draft,
) async {
  final messenger = ScaffoldMessenger.of(context);
  await showAdaptiveEntrySheet<void>(context, (sheetContext) {
    return _FinishDriveForm(draft: draft, messenger: messenger);
  });
}

class _FinishDriveForm extends ConsumerStatefulWidget {
  const _FinishDriveForm({required this.draft, required this.messenger});

  final TripDraft draft;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_FinishDriveForm> createState() => _FinishDriveFormState();
}

class _FinishDriveFormState extends ConsumerState<_FinishDriveForm> {
  final _odometer = TextEditingController();
  final _distance = TextEditingController();
  final _to = TextEditingController();
  TripPurpose _purpose = TripPurpose.private;
  String? _error;

  @override
  void dispose() {
    _odometer.dispose();
    _distance.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EntrySheetBody(
      title: l10n.tripDriveFinish,
      fields: [
        LabeledField(
          label: l10n.tripDriveOdometerNow,
          child: TextField(
            key: const Key('drive-finish-odometer'),
            controller: _odometer,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: GarageTheme.numericField(context),
          ),
        ),
        const SizedBox(height: GarageTokens.space4),
        // The way out for a car whose starting reading was never noted, and
        // for anyone who simply knows the distance.
        LabeledField(
          label: l10n.tripDistance,
          child: TextField(
            key: const Key('drive-finish-distance'),
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GarageTheme.numericField(context),
          ),
        ),
        const SizedBox(height: GarageTokens.space4),
        LabeledField(
          label: l10n.tripTo,
          child: TextField(key: const Key('drive-finish-to'), controller: _to),
        ),
        const SizedBox(height: GarageTokens.space4),
        SegmentedButton<TripPurpose>(
          segments: [
            ButtonSegment(
              value: TripPurpose.private,
              label: Text(l10n.tripPurposePrivate),
            ),
            ButtonSegment(
              value: TripPurpose.business,
              label: Text(l10n.tripPurposeBusiness),
            ),
          ],
          selected: {_purpose},
          onSelectionChanged: (value) => setState(() => _purpose = value.first),
        ),
        if (_error case final message?) ...[
          const SizedBox(height: GarageTokens.space3),
          Text(message, style: TextStyle(color: context.tokens.danger)),
        ],
      ],
      confirmLabel: l10n.tripDriveFinish,
      onConfirm: _finish,
    );
  }

  Future<void> _finish() async {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.read(unitPreferencesProvider),
    );
    final endOdometer = int.tryParse(_odometer.text.trim());
    final distance = double.tryParse(
      _distance.text.trim().replaceAll(',', '.'),
    );

    // Refuse here rather than let the domain throw: the person is looking at
    // the form and can fix it, which is not true of an error surfaced later.
    if (distance == null &&
        (endOdometer == null || widget.draft.startOdometerKm == null)) {
      setState(() => _error = l10n.tripDriveNeedsMeasure);
      return;
    }
    if (endOdometer != null &&
        widget.draft.startOdometerKm != null &&
        endOdometer < widget.draft.startOdometerKm!) {
      setState(() => _error = l10n.tripOdometerOrder);
      return;
    }

    final navigator = Navigator.of(context);
    final ok = await ref
        .read(tripDraftControllerProvider.notifier)
        .finish(
          widget.draft,
          endedAt: DateTime.now().toUtc(),
          endOdometerKm: endOdometer,
          distanceKm: distance,
          purpose: _purpose,
          toPlace: _to.text.trim().isEmpty ? null : _to.text.trim(),
        );
    if (!ok) {
      setState(() => _error = l10n.errorGeneric);
      return;
    }
    navigator.pop();
    // Naming the distance is the proof the drive landed somewhere: decision 74
    // says a save the user cannot see is a save they believe failed.
    final logged =
        distance ?? (endOdometer! - widget.draft.startOdometerKm!).toDouble();
    widget.messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.tripDriveFinished(format.formatDistance(logged))),
      ),
    );
  }
}
