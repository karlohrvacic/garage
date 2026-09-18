import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/trip_draft.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../../../domain/entities/trip_route.dart';
import '../providers/route_providers.dart';
import '../../household/providers/member_providers.dart';
import '../providers/trip_providers.dart';
import '../../observations/widgets/observation_sheet.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/discard_guard.dart';

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
          // Only when it was somebody else. In a shared garage the card
          // announces a drive you may not have started, and "finish drive"
          // means something different when the car is out with your partner.
          if (draft.createdBy != ref.watch(currentUserIdProvider))
            if (switch (ref.watch(memberNamesProvider)) {
                  AsyncData(:final value) => value[draft.createdBy],
                  _ => null,
                }
                case final name?)
              Text(
                l10n.tripDriveStartedBy(name),
                style: TextStyle(color: tokens.muted),
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
  final confirmed = await confirmDestructive(
    context,
    body: l10n.tripDriveDiscardConfirm,
    confirmLabel: l10n.tripDriveDiscard,
  );
  if (!confirmed) {
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

/// The dropdown value that means "this drive belongs to no named journey".
const _noRoute = '';

/// The dropdown value that reveals the name field.
const _newRoute = '\u0000new';

class _StartDriveFormState extends ConsumerState<_StartDriveForm> {
  final _odometer = TextEditingController();
  final _routeName = TextEditingController();
  String _route = _noRoute;
  String? _error;

  @override
  void dispose() {
    _odometer.dispose();
    _routeName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final routes = switch (ref.watch(
      routesForVehicleProvider(widget.vehicleId),
    )) {
      AsyncData(:final value) => value,
      _ => const <TripRoute>[],
    };
    return EntrySheetBody(
      title: l10n.tripDriveStart,
      fields: [
        DiscardGuard(
          controllers: [_odometer, _routeName],
          alsoDirty: () => _route != _noRoute,
        ),
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
        const SizedBox(height: GarageTokens.space4),
        // Chosen when the drive is opened rather than when it is finished: the
        // person knows where they are going now, and by the time they park the
        // question has become paperwork.
        LabeledField(
          label: l10n.routeLabel,
          child: DropdownButtonFormField<String>(
            key: const Key('drive-start-route'),
            // A long route name at a large font size otherwise pushes the
            // arrow off the right of a narrow phone.
            isExpanded: true,
            initialValue: _route,
            items: [
              DropdownMenuItem(
                value: _noRoute,
                child: Text(l10n.routeNoneOption),
              ),
              for (final route in routes)
                DropdownMenuItem(value: route.id, child: Text(route.name)),
              DropdownMenuItem(
                value: _newRoute,
                child: Text(l10n.routeNewOption),
              ),
            ],
            onChanged: (value) => setState(() => _route = value ?? _noRoute),
          ),
        ),
        if (_route == _newRoute) ...[
          const SizedBox(height: GarageTokens.space4),
          LabeledField(
            label: l10n.routeNameLabel,
            child: TextField(
              key: const Key('drive-start-route-name'),
              controller: _routeName,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l10n.routeNameHint),
            ),
          ),
        ],
        if (_error case final message?) ...[
          const SizedBox(height: GarageTokens.space3),
          Text(message, style: TextStyle(color: context.tokens.danger)),
        ],
      ],
      confirmLabel: l10n.tripDriveStart,
      onConfirm: _start,
    );
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);

    final routeId = await _routeId();
    // Naming the route failed. Starting the drive anyway would file it under
    // nothing, and the person would never know which of the two happened.
    if (routeId == _failed) {
      if (mounted) {
        setState(() => _error = l10n.routeSaveFailed);
      }
      return;
    }

    final ok = await ref
        .read(tripDraftControllerProvider.notifier)
        .start(
          vehicleId: widget.vehicleId,
          // Stamped here, not in the repository: this is the moment the
          // person said they were setting off.
          startedAt: DateTime.now().toUtc(),
          startOdometerKm: int.tryParse(_odometer.text.trim()),
          routeId: routeId,
        );
    navigator.pop();
    widget.messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.tripDriveStarted : l10n.tripDriveAlreadyOpen),
      ),
    );
  }

  /// The route to file this drive under: null for none, [_failed] when a new
  /// name could not be saved.
  Future<String?> _routeId() async {
    if (_route == _newRoute) {
      final name = _routeName.text.trim();
      if (name.isEmpty) {
        // "New route" with no name is not an error; it is somebody who
        // changed their mind and is about to drive off.
        return null;
      }
      final route = await ref
          .read(routeControllerProvider.notifier)
          .ensure(name);
      return route?.id ?? _failed;
    }
    return _route == _noRoute ? null : _route;
  }
}

/// Distinguishes "no route wanted" from "the route could not be saved", which
/// a bare null cannot.
const _failed = '\u0000failed';

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
  bool _comparable = true;
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
        // The reading at the end of a drive is typed standing beside the car,
        // and nothing else in the app knows it.
        DiscardGuard(
          controllers: [_odometer, _distance, _to],
          alsoDirty: () => _purpose != TripPurpose.private || !_comparable,
        ),
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
        // Only for a drive on a named route: for any other journey the
        // question has no consequence, and a switch with no consequence is a
        // decision asked for nothing.
        if (widget.draft.routeId != null) ...[
          const SizedBox(height: GarageTokens.space3),
          SwitchListTile(
            key: const Key('drive-finish-not-normal'),
            contentPadding: EdgeInsets.zero,
            value: !_comparable,
            onChanged: (value) => setState(() => _comparable = !value),
            title: Text(l10n.tripNotComparable),
            subtitle: Text(
              l10n.tripNotComparableHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
          comparable: _comparable,
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
        // The whole of "a diary of driving events", for the cost of one
        // action. Something noticed on a journey is an observation that points
        // at the journey; a second diary would be the same columns under
        // another name and two lists to keep filled in.
        action: SnackBarAction(
          label: l10n.tripDriveNoteSomething,
          onPressed: () => showObservationSheet(
            navigator.context,
            vehicleId: widget.draft.vehicleId,
            tripId: widget.draft.id,
          ),
        ),
      ),
    );
  }
}
