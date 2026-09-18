import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/ids.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/observation.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/observation_providers.dart';
import '../../../core/widgets/discard_guard.dart';

/// Recording something noticed, or editing it later.
Future<void> showObservationSheet(
  BuildContext context, {
  required String vehicleId,
  Observation? existing,
  String? tripId,
}) {
  return showAdaptiveEntrySheet<void>(context, (sheetContext) {
    return _ObservationForm(
      vehicleId: vehicleId,
      existing: existing,
      tripId: tripId,
    );
  });
}

class _ObservationForm extends ConsumerStatefulWidget {
  const _ObservationForm({required this.vehicleId, this.existing, this.tripId});

  final String vehicleId;
  final Observation? existing;

  /// Set when the note is being made about a journey just finished, which is
  /// what turns an observation into "something that happened on a drive".
  final String? tripId;

  @override
  ConsumerState<_ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends ConsumerState<_ObservationForm> {
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late final _odometer = TextEditingController(
    text: widget.existing?.odometerKm?.toString() ?? '',
  );
  late DateTime _noticedOn =
      widget.existing?.noticedOn ?? DateTime.now().toUtc();

  /// Minted before the first keystroke, so a photo can be taken at the car and
  /// attached before the note is written — which is the order these actually
  /// happen in.
  late final String _id = widget.existing?.id ?? newEntryId();

  /// Captured in `initState`, not read in `dispose`. A `WidgetRef` is unusable
  /// once the widget is going, and the cleanup below runs at exactly that
  /// moment — a `late final` initialiser would not help, because nothing else
  /// touches it and it would first run inside `dispose` itself.
  late final AttachmentRepository _attachments;

  bool _busy = false;
  bool _saved = false;
  AppFailure? _failure;
  final _uploads = <Future<void>>[];

  /// When the note said it was noticed as the sheet opened, so that moving
  /// the date counts as a change worth asking about.
  late final DateTime _openedOn;

  @override
  void initState() {
    super.initState();
    _attachments = ref.read(attachmentRepositoryProvider);
    _openedOn = _noticedOn;
  }

  @override
  void dispose() {
    _note.dispose();
    _odometer.dispose();
    if (widget.existing == null && !_saved) {
      // A note that was never saved takes its photo back down with it, or the
      // file hangs off a row nobody created (decision 90). Fire and forget:
      // the sheet is going, and there is nothing left to report a failure to.
      unawaited(
        discardUnsavedAttachments(
          _attachments,
          kind: AttachmentEntryKind.observation,
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
            // A photo taken at the car counts: closing a new note takes it
            // back down with it (decision 90).
            DiscardGuard(
              controllers: [_note, _odometer],
              alsoDirty: () => _noticedOn != _openedOn || _uploads.isNotEmpty,
            ),
            Text(
              widget.existing == null
                  ? l10n.observationAdd
                  : l10n.observationEdit,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.observationsHint,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space5),
            LabeledField(
              label: l10n.observationNote,
              child: TextField(
                key: const Key('observation-note'),
                controller: _note,
                autofocus: widget.existing == null,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l10n.observationNoteHint),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.observationNoticedOn,
              child: OutlinedButton(
                key: const Key('observation-date'),
                onPressed: _pickDate,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(format.formatDate(_noticedOn.toLocal())),
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.observationOdometer,
              child: TextField(
                key: const Key('observation-odometer'),
                controller: _odometer,
                keyboardType: TextInputType.number,
                style: GarageTheme.numericField(context),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            EntryAttachments(
              vehicleId: widget.vehicleId,
              kind: AttachmentEntryKind.observation,
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
              key: const Key('observation-save'),
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
      initialDate: _noticedOn,
      firstDate: firstLoggableDate(_noticedOn),
      // Already noticed: dating it ahead is a typo, not a plan.
      lastDate: lastLoggableDate(_noticedOn),
    );
    if (picked != null && mounted) {
      setState(() => _noticedOn = picked);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final note = _note.text.trim();
    if (note.isEmpty) {
      // A problem with no description is a row nobody can act on, and the
      // database refuses it anyway.
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
    final observation = existing == null
        ? Observation(
            id: _id,
            vehicleId: widget.vehicleId,
            noticedOn: _noticedOn,
            note: note,
            createdBy: '',
            createdAt: DateTime.now().toUtc(),
            tripId: widget.tripId,
            odometerKm: int.tryParse(_odometer.text.trim()),
          )
        : existing.copyWith(
            note: note,
            noticedOn: _noticedOn,
            odometerKm: int.tryParse(_odometer.text.trim()),
          );

    final ok = await ref
        .read(observationControllerProvider.notifier)
        .save(observation, isNew: existing == null);

    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() {
        _busy = false;
        _failure = ref.read(observationControllerProvider).error is AppFailure
            ? ref.read(observationControllerProvider).error! as AppFailure
            : const AppFailure(kind: AppFailureKind.unknown);
      });
      return;
    }
    _saved = true;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.observationSaved)));
  }
}
