import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/ids.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/busy_label.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/vehicle_document.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/document_providers.dart';
import '../document_type_labels.dart';

/// Adds or corrects one document.
///
/// The same form for both, like every other sheet in this app. A document is
/// edited far more often than an entry is — the expiry is retyped at every
/// renewal — so "add" and "edit" being the same screen matters more here than
/// anywhere else.
class DocumentSheet extends ConsumerStatefulWidget {
  const DocumentSheet({
    required this.vehicleId,
    this.existing,
    this.alreadyHeld = const {},
    super.key,
  });

  final String vehicleId;
  final VehicleDocument? existing;

  /// The types this vehicle already holds. One of each kind per car is what
  /// the database enforces, so offering a type that would be refused is
  /// offering a dead end.
  final Set<DocumentType> alreadyHeld;

  @override
  ConsumerState<DocumentSheet> createState() => _DocumentSheetState();
}

class _DocumentSheetState extends ConsumerState<DocumentSheet> {
  /// Minted before the first keystroke, so a photo of the paper can be
  /// attached while the document is still being typed — the same trick every
  /// entry sheet uses, and the reason a save that timed out lands as the same
  /// row rather than a second one.
  late final String _id = widget.existing?.id ?? newEntryId();

  final _label = TextEditingController();
  final _number = TextEditingController();
  final _issuer = TextEditingController();
  final _notes = TextEditingController();

  DocumentType _type = DocumentType.registration;
  DateTime? _issuedOn;
  DateTime? _expiresOn;

  bool _busy = false;
  AppFailure? _failure;
  bool _labelMissing = false;
  bool _attachedAny = false;
  final _uploads = <Future<void>>[];

  /// Whether the document reached the database, and whether the attempt was
  /// even made. Both, because decision 90's rule holds here too: a save that
  /// timed out or was refused may still have landed, so its receipt is left
  /// alone rather than deleted off a row that exists.
  bool _saved = false;
  bool _attemptedWrite = false;

  /// Captured while the widget is still mounted. `ref` is unsafe in
  /// [dispose] — it reads through the BuildContext the framework has already
  /// deactivated — and this cleanup runs precisely then.
  late final AttachmentRepository _attachments;

  @override
  void initState() {
    super.initState();
    _attachments = ref.read(attachmentRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      // Open on a type the car does not already hold: the commonest reason to
      // add a second document is that the first one is not the one you meant.
      _type = DocumentType.values.firstWhere(
        (type) => !widget.alreadyHeld.contains(type),
        orElse: () => DocumentType.other,
      );
      return;
    }
    _type = existing.type;
    _label.text = existing.label ?? '';
    _number.text = existing.number ?? '';
    _issuer.text = existing.issuer ?? '';
    _notes.text = existing.notes ?? '';
    _issuedOn = existing.issuedOn;
    _expiresOn = existing.expiresOn;
  }

  @override
  void dispose() {
    _label.dispose();
    _number.dispose();
    _issuer.dispose();
    _notes.dispose();
    if (widget.existing == null && !_saved && !_attemptedWrite) {
      // A document that was never saved takes its attachments back down with
      // it, or the file hangs off a row nobody created. Fire and forget: the
      // sheet is going, and there is nothing left to report a failure to.
      unawaited(
        discardUnsavedAttachments(
          _attachments,
          kind: AttachmentEntryKind.document,
          entryId: _id,
          pending: _uploads,
        ),
      );
    }
    super.dispose();
  }

  String? _trimmed(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required bool future,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final today = DateTime.now();
    final initial = current ?? today;
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: initial,
      // An expiry is ahead and an issue date is behind, and a picker that
      // opens ten years the wrong way is a scroll nobody should have to do.
      firstDate: future ? DateTime(today.year - 1) : firstLoggableDate(initial),
      lastDate: future ? DateTime(today.year + 15) : lastLoggableDate(initial),
    );
    if (picked != null) {
      setState(
        () => onPicked(DateTime.utc(picked.year, picked.month, picked.day)),
      );
    }
  }

  bool get _datesOutOfOrder {
    final issued = _issuedOn;
    final expires = _expiresOn;
    return issued != null && expires != null && expires.isBefore(issued);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_type == DocumentType.other && _trimmed(_label) == null) {
      setState(() => _labelMissing = true);
      return;
    }
    if (_datesOutOfOrder) {
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });

    final document = VehicleDocument(
      id: _id,
      vehicleId: widget.vehicleId,
      type: _type,
      // Only `other` has a label to carry. Without this, typing a name under
      // "other" and then switching the type back writes the text onto a
      // registration certificate, where `documentTitle` prefers it and the
      // card reads as whatever was typed.
      label: _type == DocumentType.other ? _trimmed(_label) : null,
      number: _trimmed(_number),
      issuer: _trimmed(_issuer),
      issuedOn: _issuedOn,
      expiresOn: _expiresOn,
      notes: _trimmed(_notes),
      createdBy: widget.existing?.createdBy ?? '',
    );

    _attemptedWrite = true;
    try {
      await writeWithTimeout(
        ref.read(documentRepositoryProvider).save(document),
      );
      _saved = true;
      await _syncReminder(document);
      ref.invalidate(vehicleDocumentsProvider(widget.vehicleId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.documentSaved)));
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

  /// Points the paperwork reminder at this document's own expiry.
  ///
  /// Documents deliberately reuse the maintenance service types rather than
  /// inventing a parallel due-date system: that is what makes a registration
  /// turn up on the dashboard, in the planner and in a notification without
  /// any of them learning what a document is.
  ///
  /// It also means the cost sheet and this sheet write the *same* rule. That
  /// is the intended behaviour rather than a collision — paying for a
  /// registration and recording the certificate are two halves of one fact —
  /// and the later of the two wins, which is the document whenever a
  /// household keeps one, because it carries the date printed on the paper
  /// instead of twelve months from the payment.
  ///
  /// Failures are swallowed: the document is what the person came to record,
  /// and failing the save over the reminder on top of it would invite a retry
  /// and a second row.
  Future<void> _syncReminder(VehicleDocument document) async {
    final key = document.type.serviceTypeKey;
    // A document whose *type* was corrected leaves the old type's reminder
    // standing otherwise — and nothing settles a paperwork rule except
    // recording the paperwork again, so the orphan is effectively permanent.
    // That is the shape the cost sheet's own retraction was written to avoid.
    final previous = widget.existing?.type.serviceTypeKey;
    final stale = previous != null && previous != key ? previous : null;

    // Clearing the standing rule is how an expiry is *retracted* — but only
    // this document's own expiry. A registration certificate filed with just
    // its number and no date must not take down the reminder the *cost* sheet
    // raised when the registration was paid: nothing on screen would say why
    // the planner entry vanished, and nothing but paying again brings a
    // paperwork rule back.
    //
    // So: clear when this document has an expiry to replace it with, or when
    // it had one and no longer does. Not when it has never had one.
    final hadExpiry = widget.existing?.expiresOn != null;
    final clearing = document.expiresOn != null || hadExpiry;
    final keys = [if (clearing) ?key, ?stale];
    if (keys.isEmpty) {
      return;
    }
    try {
      final repository = ref.read(maintenanceRepositoryProvider);
      await writeWithTimeout(
        repository.completeOneTimeRules(widget.vehicleId, keys),
      );
      final expires = document.expiresOn;
      if (key != null && expires != null) {
        await writeWithTimeout(
          repository.upsertRule(
            ReminderRule(
              id: '',
              vehicleId: widget.vehicleId,
              serviceTypeKey: key,
              oneTime: true,
              dueDate: expires,
              // What the cycle started from, so the planner's progress bar
              // measures the real period rather than from the day the row was
              // typed in. Falling back to a year before the expiry is the
              // honest guess for paperwork that is annual by law.
              issuedDate:
                  document.issuedOn ??
                  DateTime.utc(expires.year - 1, expires.month, expires.day),
            ),
          ),
        );
      }
      ref
        ..invalidate(reminderRulesProvider(widget.vehicleId))
        ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
    } catch (_) {
      // The document is saved; the reminder is a courtesy on top of it.
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || !await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await writeWithTimeout(
        ref.read(documentRepositoryProvider).delete(existing.id),
      );
      await _retractOwnReminder(existing);
      ref.invalidate(vehicleDocumentsProvider(widget.vehicleId));
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

  /// Clears the reminder this document raised, if it is still standing.
  ///
  /// Matched on the due date rather than on the service type alone: a
  /// household that also pays for the registration in the cost sheet has a
  /// rule of the same type dated from the payment, and deleting a document
  /// must not silently take that one down with it.
  Future<void> _retractOwnReminder(VehicleDocument existing) async {
    final key = existing.type.serviceTypeKey;
    final expires = existing.expiresOn;
    if (key == null || expires == null) {
      return;
    }
    try {
      final rules = await ref.read(
        reminderRulesProvider(widget.vehicleId).future,
      );
      final mine = rules.any(
        (rule) =>
            rule.active &&
            rule.oneTime &&
            rule.serviceTypeKey == key &&
            rule.dueDate == expires,
      );
      if (!mine) {
        return;
      }
      await writeWithTimeout(
        ref.read(maintenanceRepositoryProvider).completeOneTimeRules(
          widget.vehicleId,
          [key],
        ),
      );
      ref
        ..invalidate(reminderRulesProvider(widget.vehicleId))
        ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
    } catch (_) {
      // The row the person asked to be rid of is already gone.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    // Every type, minus the ones this car already holds — except the one
    // being edited, which is obviously held by itself.
    final offered = [
      for (final type in DocumentType.values)
        if (type == DocumentType.other ||
            type == widget.existing?.type ||
            !widget.alreadyHeld.contains(type))
          type,
    ];

    Widget dateRow({
      required String label,
      required DateTime? value,
      required bool future,
      required ValueChanged<DateTime?> onPicked,
    }) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(
          value == null ? l10n.documentDateNotSet : format.formatDate(value),
          style: value == null ? TextStyle(color: context.tokens.muted) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              IconButton(
                tooltip: l10n.documentClearDate,
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => onPicked(null)),
              ),
            const Icon(Icons.calendar_today),
          ],
        ),
        onTap: () =>
            _pickDate(current: value, future: future, onPicked: onPicked),
      );
    }

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
              DiscardGuard(
                alsoDirty: () => _attachedAny,
                controllers: [_label, _number, _issuer, _notes],
              ),
              Text(
                widget.existing == null ? l10n.documentAdd : l10n.documentEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space4),
              LabeledField(
                label: l10n.documentType,
                child: DropdownButtonFormField<DocumentType>(
                  key: const Key('document-type'),
                  initialValue: offered.contains(_type) ? _type : offered.first,
                  isExpanded: true,
                  items: [
                    for (final type in offered)
                      DropdownMenuItem(
                        value: type,
                        child: Text(documentTypeLabel(l10n, type)),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _type = value ?? _type;
                    _labelMissing = false;
                  }),
                ),
              ),
              if (_type == DocumentType.other) ...[
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.documentLabel,
                  child: TextField(
                    key: const Key('document-label'),
                    controller: _label,
                    decoration: InputDecoration(
                      helperText: l10n.documentLabelHint,
                      errorText: _labelMissing
                          ? l10n.documentLabelRequired
                          : null,
                    ),
                    onChanged: (_) => setState(() => _labelMissing = false),
                  ),
                ),
              ],
              const SizedBox(height: GarageTokens.space3),
              dateRow(
                label: l10n.documentExpiresOn,
                value: _expiresOn,
                future: true,
                onPicked: (value) => _expiresOn = value,
              ),
              dateRow(
                label: l10n.documentIssuedOn,
                value: _issuedOn,
                future: false,
                onPicked: (value) => _issuedOn = value,
              ),
              if (_datesOutOfOrder)
                Text(
                  l10n.documentDatesOutOfOrder,
                  style: TextStyle(color: context.tokens.danger),
                ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.documentNumber,
                child: TextField(
                  key: const Key('document-number'),
                  controller: _number,
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.documentIssuer,
                child: TextField(controller: _issuer),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
              const SizedBox(height: GarageTokens.space3),
              // Why this row exists at all: a document nobody is reminded
              // about is a photo in a drawer.
              Text(
                _type.serviceTypeKey == null
                    ? l10n.documentNoReminderNote
                    : l10n.documentReminderNote,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space3),
              EntryAttachments(
                vehicleId: widget.vehicleId,
                kind: AttachmentEntryKind.document,
                entryId: _id,
                onUpload: (upload) {
                  _attachedAny = true;
                  _uploads.add(upload);
                },
              ),
              if (_failure != null) ...[
                const SizedBox(height: GarageTokens.space3),
                Text(
                  '${failureMessage(l10n, _failure!)} ${l10n.saveEntryKept}',
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: BusyLabel(busy: _busy, child: Text(l10n.commonSave)),
              ),
              StillSavingNote(busy: _busy),
              if (widget.existing != null) ...[
                const SizedBox(height: GarageTokens.space3),
                OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  child: Text(l10n.commonDelete),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet the way every other entry form in the app opens: a bottom
/// sheet on a phone, a centred dialog on a desktop window.
Future<bool?> showDocumentSheet(
  BuildContext context, {
  required String vehicleId,
  VehicleDocument? existing,
  Set<DocumentType> alreadyHeld = const {},
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => DocumentSheet(
      vehicleId: vehicleId,
      existing: existing,
      alreadyHeld: alreadyHeld,
    ),
  );
}
