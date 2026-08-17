import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../../domain/trips/trip_log.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/fleet_trip_providers.dart';
import '../providers/trip_providers.dart';

/// Opens the trip sheet and returns true if a trip was saved.
Future<bool?> showTripEntrySheet(
  BuildContext context,
  String vehicleId, {
  TripEntry? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => TripEntrySheet(vehicleId: vehicleId, existing: existing),
  );
}

class TripEntrySheet extends ConsumerStatefulWidget {
  const TripEntrySheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final TripEntry? existing;

  @override
  ConsumerState<TripEntrySheet> createState() => _TripEntrySheetState();
}

class _TripEntrySheetState extends ConsumerState<TripEntrySheet> {
  final _title = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _distance = TextEditingController();
  final _startOdometer = TextEditingController();
  final _endOdometer = TextEditingController();
  final _minutes = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  TripPurpose _purpose = TripPurpose.private;
  bool _busy = false;
  bool _distanceMissing = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    _date = existing.date.toLocal();
    _purpose = existing.purpose;
    _title.text = existing.title ?? '';
    _from.text = existing.fromPlace ?? '';
    _to.text = existing.toPlace ?? '';
    _distance.text = prefs.kmToDisplay(existing.distanceKm).toStringAsFixed(1);
    _startOdometer.text = existing.startOdometerKm == null
        ? ''
        : prefs
              .kmToDisplay(existing.startOdometerKm!.toDouble())
              .round()
              .toString();
    _endOdometer.text = existing.endOdometerKm == null
        ? ''
        : prefs
              .kmToDisplay(existing.endOdometerKm!.toDouble())
              .round()
              .toString();
    _minutes.text = existing.minutes?.toString() ?? '';
    _notes.text = existing.notes ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _from.dispose();
    _to.dispose();
    _distance.dispose();
    _startOdometer.dispose();
    _endOdometer.dispose();
    _minutes.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  double? _parse(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  int? _odometerKm(TextEditingController controller) {
    final typed = _parse(controller);
    return typed == null
        ? null
        : ref.read(unitPreferencesProvider).displayToKm(typed).round();
  }

  /// Typing both odometer readings fills the distance in, because a driver who
  /// has just read the trip off the dashboard should not then be asked to
  /// subtract. Typing over it afterwards still wins.
  void _fillDistanceFromOdometer() {
    final derived = TripLog.distanceBetween(
      start: _odometerKm(_startOdometer),
      end: _odometerKm(_endOdometer),
    );
    // Always rebuild, even when the range implies nothing: a range that runs
    // backwards has to be able to say so, and that message is drawn from this
    // build.
    setState(() {
      if (derived == null) {
        return;
      }
      _distanceMissing = false;
      _distance.text = ref
          .read(unitPreferencesProvider)
          .kmToDisplay(derived)
          .toStringAsFixed(1);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _distanceMissing = false;
      _failure = null;
    });

    final prefs = ref.read(unitPreferencesProvider);
    final start = _odometerKm(_startOdometer);
    final end = _odometerKm(_endOdometer);
    final typed = _parse(_distance);
    final distanceKm = typed != null
        ? prefs.displayToKm(typed)
        : TripLog.distanceBetween(start: start, end: end);

    if (distanceKm == null || distanceKm < 0) {
      setState(() => _distanceMissing = true);
      return;
    }

    setState(() => _busy = true);

    final entry = TripEntry(
      id: widget.existing?.id ?? '',
      vehicleId: widget.vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      distanceKm: distanceKm,
      purpose: _purpose,
      createdBy: widget.existing?.createdBy ?? '',
      title: _emptyToNull(_title),
      fromPlace: _emptyToNull(_from),
      toPlace: _emptyToNull(_to),
      startOdometerKm: start,
      endOdometerKm: end,
      minutes: _parse(_minutes)?.round(),
      notes: _emptyToNull(_notes),
    );

    try {
      final repository = ref.read(tripRepositoryProvider);
      if (widget.existing == null) {
        await repository.add(entry);
      } else {
        await repository.update(entry);
      }
      _invalidate();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref.read(tripRepositoryProvider).delete(widget.existing!.id);
      _invalidate();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  /// A trip that recorded an end reading has moved the odometer, so the
  /// projections that measure against it have to be recomputed.
  void _invalidate() {
    ref
      ..invalidate(tripEntriesProvider(widget.vehicleId))
      ..invalidate(allTripsProvider)
      ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
  }

  String? _emptyToNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final start = _odometerKm(_startOdometer);
    final end = _odometerKm(_endOdometer);
    final outOfOrder = start != null && end != null && end < start;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.tripAdd, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: GarageTokens.space4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.costDate),
                subtitle: Text(format.formatShortDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              // The purpose is first among the fields because it is the one
              // that makes a logbook worth keeping, and the one people forget.
              LabeledField(
                label: l10n.tripPurpose,
                child: SegmentedButton<TripPurpose>(
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
                  onSelectionChanged: (values) =>
                      setState(() => _purpose = values.first),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.tripTitleField,
                child: TextField(controller: _title),
              ),
              const SizedBox(height: GarageTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: l10n.tripFrom,
                      child: TextField(controller: _from),
                    ),
                  ),
                  const SizedBox(width: GarageTokens.space3),
                  Expanded(
                    child: LabeledField(
                      label: l10n.tripTo,
                      child: TextField(controller: _to),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarageTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: l10n.tripStartOdometer,
                      child: TextField(
                        key: const Key('trip-start-odometer'),
                        controller: _startOdometer,
                        keyboardType: TextInputType.number,
                        style: GarageTheme.numericField(context),
                        onChanged: (_) => _fillDistanceFromOdometer(),
                      ),
                    ),
                  ),
                  const SizedBox(width: GarageTokens.space3),
                  Expanded(
                    child: LabeledField(
                      label: l10n.tripEndOdometer,
                      child: TextField(
                        key: const Key('trip-end-odometer'),
                        controller: _endOdometer,
                        keyboardType: TextInputType.number,
                        style: GarageTheme.numericField(context),
                        decoration: InputDecoration(
                          errorText: outOfOrder ? l10n.tripOdometerOrder : null,
                        ),
                        onChanged: (_) => _fillDistanceFromOdometer(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarageTokens.space3),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: l10n.tripDistance,
                      child: TextField(
                        key: const Key('trip-distance'),
                        controller: _distance,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GarageTheme.numericField(context),
                        decoration: InputDecoration(
                          errorText: _distanceMissing
                              ? l10n.tripDistanceRequired
                              : null,
                        ),
                        onChanged: (_) =>
                            setState(() => _distanceMissing = false),
                      ),
                    ),
                  ),
                  const SizedBox(width: GarageTokens.space3),
                  Expanded(
                    child: LabeledField(
                      label: l10n.tripMinutes,
                      child: TextField(
                        key: const Key('trip-minutes'),
                        controller: _minutes,
                        keyboardType: TextInputType.number,
                        style: GarageTheme.numericField(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
              if (_failure != null) ...[
                const SizedBox(height: GarageTokens.space3),
                Text(
                  failureMessage(l10n, _failure!),
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy || outOfOrder ? null : _submit,
                child: Text(l10n.commonSave),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space3),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.tokens.danger,
                  ),
                  label: Text(
                    l10n.commonDelete,
                    style: TextStyle(color: context.tokens.danger),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
