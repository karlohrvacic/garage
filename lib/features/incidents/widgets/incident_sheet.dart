import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/ids.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/incident.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../company/widgets/driver_on_date.dart';
import '../../settings/providers/unit_providers.dart';
import '../incident_labels.dart';
import '../providers/incident_providers.dart';

/// Reporting what happened to the car, or editing the report later.
Future<void> showIncidentSheet(
  BuildContext context, {
  required String vehicleId,
  Incident? existing,
}) {
  return showAdaptiveEntrySheet<void>(
    context,
    (sheetContext) => _IncidentForm(vehicleId: vehicleId, existing: existing),
  );
}

class _IncidentForm extends ConsumerStatefulWidget {
  const _IncidentForm({required this.vehicleId, this.existing});

  final String vehicleId;
  final Incident? existing;

  @override
  ConsumerState<_IncidentForm> createState() => _IncidentFormState();
}

class _IncidentFormState extends ConsumerState<_IncidentForm> {
  late IncidentKind _kind = widget.existing?.kind ?? IncidentKind.damage;
  late IncidentStatus _status = widget.existing?.status ?? IncidentStatus.open;

  /// A UTC calendar day throughout, as the entity carries it. A new report
  /// defaults to the day it is where the phone is, not the UTC instant's:
  /// one in the morning in Croatia is still yesterday in UTC, and a report
  /// filed under yesterday could not be closed tonight.
  late DateTime _happenedOn;
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _odometer = TextEditingController(
    text: widget.existing?.odometerKm?.toString() ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.existing?.amount?.toStringAsFixed(2) ?? '',
  );

  /// Minted before the first keystroke, so the photo of the dent can be
  /// taken at the car and attached before a word is typed (decision 90).
  late final String _id = widget.existing?.id ?? newEntryId();

  /// Captured in `initState`, not read in `dispose`: a `WidgetRef` is
  /// unusable once the widget is going, and the cleanup below runs then.
  late final AttachmentRepository _attachments;

  /// What the choices were as the sheet opened, so that moving the date or
  /// the status counts as a change worth asking about.
  late final DateTime _openedOn;
  late final IncidentKind _openedKind;
  late final IncidentStatus _openedStatus;

  bool _busy = false;
  bool _saved = false;
  AppFailure? _failure;
  final _uploads = <Future<void>>[];

  @override
  void initState() {
    super.initState();
    _attachments = ref.read(attachmentRepositoryProvider);
    _happenedOn = widget.existing?.happenedOn ?? _day(ref.read(todayProvider));
    _openedOn = _happenedOn;
    _openedKind = _kind;
    _openedStatus = _status;
  }

  DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  @override
  void dispose() {
    _description.dispose();
    _odometer.dispose();
    _amount.dispose();
    if (widget.existing == null && !_saved) {
      // A report never saved takes its photos back down with it, or they
      // hang off a row nobody created (decision 90).
      unawaited(
        discardUnsavedAttachments(
          _attachments,
          kind: AttachmentEntryKind.incident,
          entryId: _id,
          pending: _uploads,
        ),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DiscardGuard(
              controllers: [_description, _odometer, _amount],
              alsoDirty: () =>
                  _happenedOn != _openedOn ||
                  _kind != _openedKind ||
                  _status != _openedStatus ||
                  _uploads.isNotEmpty,
            ),
            Text(
              widget.existing == null ? l10n.incidentAdd : l10n.incidentEdit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.incidentsHint,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space5),
            LabeledField(
              label: l10n.incidentKind,
              child: Wrap(
                spacing: GarageTokens.space2,
                children: [
                  for (final kind in IncidentKind.values)
                    ChoiceChip(
                      key: Key('incident-kind-${kind.key}'),
                      label: Text(incidentKindLabel(l10n, kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.incidentHappenedOn,
              child: OutlinedButton(
                key: const Key('incident-date'),
                onPressed: _pickDate,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(format.formatDate(_happenedOn)),
                ),
              ),
            ),
            DriverOnDate(vehicleId: widget.vehicleId, date: _happenedOn),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.incidentDescription,
              child: TextField(
                key: const Key('incident-description'),
                controller: _description,
                autofocus: widget.existing == null,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.incidentDescriptionHint,
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.incidentOdometer,
                    child: TextField(
                      key: const Key('incident-odometer'),
                      controller: _odometer,
                      keyboardType: TextInputType.number,
                      style: GarageTheme.numericField(context),
                    ),
                  ),
                ),
                const SizedBox(width: GarageTokens.space3),
                Expanded(
                  child: LabeledField(
                    label: l10n.incidentAmount,
                    child: TextField(
                      key: const Key('incident-amount'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GarageTheme.numericField(context),
                      decoration: InputDecoration(
                        hintText: l10n.incidentAmountHint,
                        suffixText: format.currencySymbol,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // The status is the admin's to move between the open ones; on a
            // new report it is open by definition, and a field with one
            // answer is not asked. Settling is the card's act, which writes
            // the day with the word, so a settled report shows its status
            // and does not offer to change it.
            if (widget.existing case final existing?) ...[
              const SizedBox(height: GarageTokens.space4),
              LabeledField(
                label: l10n.incidentStatus,
                child: existing.isOpen
                    ? DropdownButtonFormField<IncidentStatus>(
                        key: const Key('incident-status'),
                        initialValue: _status,
                        isExpanded: true,
                        items: [
                          for (final status in IncidentStatus.values)
                            if (!status.isSettled)
                              DropdownMenuItem(
                                value: status,
                                child: Text(incidentStatusLabel(l10n, status)),
                              ),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      )
                    : Text(incidentStatusLabel(l10n, existing.status)),
              ),
            ],
            const SizedBox(height: GarageTokens.space4),
            EntryAttachments(
              vehicleId: widget.vehicleId,
              kind: AttachmentEntryKind.incident,
              entryId: _id,
              // Through setState, so the discard guard sees it: it reads
              // what was attached as of its last build.
              onUpload: (upload) => setState(() => _uploads.add(upload)),
            ),
            if (_failure case final failure?) ...[
              const SizedBox(height: GarageTokens.space3),
              Text(
                failureMessage(l10n, failure),
                style: TextStyle(color: context.tokens.danger),
              ),
            ],
            const SizedBox(height: GarageTokens.space5),
            FilledButton(
              key: const Key('incident-save'),
              onPressed: _busy ? null : _save,
              child: Text(l10n.commonSave),
            ),
            StillSavingNote(busy: _busy),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: _happenedOn,
      firstDate: firstLoggableDate(_happenedOn),
      // Already happened: dating it ahead is a typo, not a plan.
      lastDate: lastLoggableDate(_happenedOn),
    );
    if (picked != null && mounted) {
      setState(() => _happenedOn = _day(picked));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final description = _description.text.trim();
    if (description.isEmpty) {
      // A report with no words is a row nobody can act on, and the database
      // refuses it anyway.
      setState(() => _failure = const AppFailure(kind: AppFailureKind.invalid));
      return;
    }
    // An emptied field clears the value; one that is not a number is
    // refused, since dropping it would clear a fine somebody typed over.
    final amount = _amount.text.trim().replaceAll(',', '.');
    final odometer = _odometer.text.trim();
    if ((amount.isNotEmpty && double.tryParse(amount) == null) ||
        (odometer.isNotEmpty && int.tryParse(odometer) == null)) {
      setState(() => _failure = const AppFailure(kind: AppFailureKind.invalid));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _failure = null;
    });

    final existing = widget.existing;
    // Never the day it was settled, and never a settled status: the field
    // moves a report between the open statuses, and settling it is the
    // card's own act, which writes that day with the word.
    final incident = existing == null
        ? Incident(
            id: _id,
            vehicleId: widget.vehicleId,
            kind: _kind,
            happenedOn: _happenedOn,
            description: description,
            createdBy: '',
            createdAt: DateTime.now().toUtc(),
            odometerKm: int.tryParse(odometer),
            amount: double.tryParse(amount),
          )
        : existing.copyWith(
            kind: _kind,
            happenedOn: _happenedOn,
            description: description,
            odometerKm: int.tryParse(odometer),
            amount: double.tryParse(amount),
            status: existing.isOpen ? _status : existing.status,
          );

    final ok = await ref
        .read(incidentControllerProvider.notifier)
        .save(incident, isNew: existing == null);
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() {
        _busy = false;
        _failure = failureOf(ref.read(incidentControllerProvider));
      });
      return;
    }
    _saved = true;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.incidentSaved)));
  }
}
