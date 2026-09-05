import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/busy_label.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/format/amount_expression.dart';
import '../../../domain/maintenance/tracking_level.dart';
import '../../../domain/entities/attachment.dart';
import '../../attachments/data/attachment_repository.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../attachments/widgets/entry_attachments.dart';
import '../../settings/providers/unit_providers.dart';
import '../data/maintenance_repository.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../providers/maintenance_providers.dart';
import '../../../domain/entries/duplicate_entry.dart';
import '../service_type_labels.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../core/ids.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/amount_calculator_dock.dart';
import '../../vehicles/widgets/sheet_vehicle_row.dart';
import 'reminder_rule_sheet.dart'
    show commonServiceTypes, paperworkServiceTypes;

Future<bool?> showServiceEntrySheet(
  BuildContext context,
  String vehicleId, {
  ServiceEntry? existing,
  Set<String> initialServiceTypeKeys = const {},
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => ServiceEntrySheet(
      vehicleId: vehicleId,
      existing: existing,
      initialServiceTypeKeys: initialServiceTypeKeys,
    ),
  );
}

class ServiceEntrySheet extends ConsumerStatefulWidget {
  const ServiceEntrySheet({
    required this.vehicleId,
    this.existing,
    this.initialServiceTypeKeys = const {},
    super.key,
  });

  final String vehicleId;

  /// Ticked on open, for a sheet reached from somewhere that already knows
  /// what is being done — the planner's bundle, where the whole point is that
  /// these three items are happening in one visit. Ignored when editing, which
  /// carries its own.
  final Set<String> initialServiceTypeKeys;
  final ServiceEntry? existing;

  @override
  ConsumerState<ServiceEntrySheet> createState() => _ServiceEntrySheetState();
}

class _ServiceEntrySheetState extends ConsumerState<ServiceEntrySheet> {
  /// The car the work was done on. Held in state rather than read from the
  /// widget: a new entry may be moved to another car before it is saved.
  late String _vehicleId = widget.vehicleId;

  /// Chosen once, so a save retried after a timeout is the same entry.
  late final _newId = newEntryId();

  /// Whether the entry reached the repository. Until it does, anything
  /// attached hangs off an id nothing else knows about, and closing the sheet
  /// has to take it back down.
  bool _saved = false;

  /// Whether a write was ever started. A save that times out is not a save
  /// that failed — the request cannot be cancelled and may well have landed —
  /// so from here the cleanup keeps its hands off. An orphaned file costs
  /// storage; deleting a receipt off a real entry costs the household its
  /// paperwork.
  bool _attemptedWrite = false;

  /// Uploads still in flight. The cleanup waits for them: a file picked and
  /// then abandoned mid-upload would otherwise be inserted after the query
  /// that was meant to find it, and nothing would ever list it again.
  final _uploads = <Future<void>>[];

  /// Whether anything was attached in this sheet, which makes it dirty: a
  /// receipt is worth more than the fields around it, and dismissing the
  /// sheet by tapping outside used to take it with no question asked.
  bool _attachedAny = false;

  /// Read in [initState], while there is still a ref to read it with: the
  /// cleanup runs from [dispose], where the element is already going away and
  /// a lazy read would throw.
  late final AttachmentRepository _attachments;
  final _odometer = TextEditingController();
  final _cost = TextEditingController();
  final _costFocus = FocusNode();
  final _partsCostFocus = FocusNode();
  final _laborCostFocus = FocusNode();
  final _shop = TextEditingController();
  final _notes = TextEditingController();
  final _partsCost = TextEditingController();
  final _laborCost = TextEditingController();
  final _partsDetail = TextEditingController();
  final _faultCodes = TextEditingController();

  /// One controller per reading the household can take, created lazily so a
  /// basic household allocates nothing it will never show.
  final _readings = <String, TextEditingController>{};
  bool _diy = false;
  DateTime? _warrantyUntil;

  DateTime _date = DateTime.now();
  final Set<String> _selectedKeys = {};

  /// Statutory types this sheet opened with. They are hidden from a new
  /// entry, but one already on the entry stays offered even after it is
  /// unticked: without this, deselecting it removed the only chip that
  /// could put it back.
  final Set<String> _keptStatutory = {};
  bool _busy = false;
  bool _odometerMissing = false;
  String? _selectionError;
  AppFailure? _failure;

  @override
  void dispose() {
    if (widget.existing == null && !_saved && !_attemptedWrite) {
      // Fire and forget: the sheet is going, and there is nothing left to
      // report a failed cleanup to.
      unawaited(
        discardUnsavedAttachments(
          _attachments,
          pending: _uploads,
          kind: AttachmentEntryKind.service,
          entryId: _newId,
        ),
      );
    }
    _odometer.dispose();
    _cost.dispose();
    _costFocus.dispose();
    _partsCostFocus.dispose();
    _laborCostFocus.dispose();
    _shop.dispose();
    _notes.dispose();
    _partsCost.dispose();
    _laborCost.dispose();
    _partsDetail.dispose();
    _faultCodes.dispose();
    for (final controller in _readings.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _attachments = ref.read(attachmentRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      // A new entry opened from somewhere that already knows what is being
      // done — the planner's bundle — arrives with its items ticked.
      _selectedKeys.addAll(widget.initialServiceTypeKeys);
      _keptStatutory.addAll(widget.initialServiceTypeKeys);
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    _date = existing.date.toLocal();
    _selectedKeys.addAll(existing.serviceTypeKeys);
    _keptStatutory.addAll(existing.serviceTypeKeys);
    _odometer.text = prefs
        .kmToDisplay(existing.odometerKm.toDouble())
        .round()
        .toString();
    if (existing.cost != null) {
      _cost.text = existing.cost!.toStringAsFixed(2);
    }
    _shop.text = existing.shop ?? '';
    _notes.text = existing.notes ?? '';
    _diy = existing.diy;
    _partsDetail.text = existing.partsDetail ?? '';
    _faultCodes.text = existing.faultCodes ?? '';
    _warrantyUntil = existing.warrantyUntil?.toLocal();
    if (existing.partsCost != null) {
      _partsCost.text = existing.partsCost!.toStringAsFixed(2);
    }
    if (existing.laborCost != null) {
      _laborCost.text = existing.laborCost!.toStringAsFixed(2);
    }
    for (final reading in existing.measurements.entries) {
      _reading(reading.key).text = UnitFormat.editableNumber(
        reading.value,
        decimals: 2,
      );
    }
  }

  TextEditingController _reading(String key) =>
      _readings[key] ??= TextEditingController();

  /// Ticked jobs belong to the car they were ticked for: a diesel's filter
  /// is not offered on a petrol, and its reading would be saved against a car
  /// that never has one. The odometer goes too — it was read off the other
  /// car's dial.
  void _switchVehicle(String vehicleId) {
    setState(() {
      _vehicleId = vehicleId;
      _selectedKeys.clear();
      _keptStatutory.clear();
      _selectionError = null;
      // The complaints belonged to the previous car and to a save that is no
      // longer being attempted. Leaving them up accuses the household of a
      // mistake in a field this switch has just emptied.
      _odometerMissing = false;
      _failure = null;
      _odometer.clear();
      for (final controller in _readings.values) {
        controller.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: _date,
      firstDate: firstLoggableDate(_date),
      // Already happened: dating it ahead is a typo, not a plan.
      lastDate: lastLoggableDate(_date),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  double? _parse(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return normalized.isEmpty ? null : double.tryParse(normalized);
  }

  /// Money fields take a sum as well as a number — parts bought twice, labour
  /// split over two visits — which an odometer reading never does.
  double? _parseMoney(String raw) => evaluateAmount(raw);

  Future<void> _pickWarrantyDate() async {
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: _warrantyUntil ?? _date,
      firstDate: firstLoggableDate(_warrantyUntil ?? _date),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _warrantyUntil = picked);
    }
  }

  Future<void> _submit(UnitPreferences prefs) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _odometerMissing = false);
    if (_selectedKeys.isEmpty) {
      setState(() => _selectionError = l10n.maintenanceServiceItems);
      return;
    }
    final odometerDisplay = _parse(_odometer.text);
    if (odometerDisplay == null || odometerDisplay < 0) {
      setState(() => _odometerMissing = true);
      return;
    }

    setState(() {
      _busy = true;
      _selectionError = null;
      _failure = null;
    });

    final entry = ServiceEntry(
      id: widget.existing?.id ?? _newId,
      vehicleId: _vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      odometerKm: prefs.displayToKm(odometerDisplay).round(),
      serviceTypeKeys: _selectedKeys.toList(growable: false),
      cost: _parseMoney(_cost.text),
      shop: _shop.text.trim().isEmpty ? null : _shop.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
      diy: _diy,
      partsCost: _parseMoney(_partsCost.text),
      laborCost: _parseMoney(_laborCost.text),
      partsDetail: _partsDetail.text.trim().isEmpty
          ? null
          : _partsDetail.text.trim(),
      warrantyUntil: _warrantyUntil == null
          ? null
          : DateTime.utc(
              _warrantyUntil!.year,
              _warrantyUntil!.month,
              _warrantyUntil!.day,
            ),
      faultCodes: _faultCodes.text.trim().isEmpty
          ? null
          : _faultCodes.text.trim(),
      measurements: {
        // A reading left blank parses to null and is simply not recorded.
        for (final entry in _readings.entries)
          if (_parse(entry.value.text) != null)
            entry.key: _parse(entry.value.text)!,
      },
    );

    try {
      // Set before the write, not after: a write that times out may still
      // have landed, and the cleanup must not delete the receipts off an
      // entry that exists. An orphan costs storage; this costs the household
      // its paperwork.
      _attemptedWrite = true;
      if (widget.existing == null) {
        await writeNew(
          () => ref.read(maintenanceRepositoryProvider).addServiceEntry(entry),
        );
        // Immediately: the entry exists from here, whatever the follow-up
        // work does.
        _saved = true;
        await writeWithTimeout(
          ref
              .read(maintenanceRepositoryProvider)
              .completeOneTimeRules(_vehicleId, entry.serviceTypeKeys),
        );
      } else {
        await writeWithTimeout(
          ref.read(maintenanceRepositoryProvider).updateServiceEntry(entry),
        );
      }
      ref.invalidate(serviceEntriesProvider(_vehicleId));
      ref.invalidate(vehicleProjectionsProvider(_vehicleId));
      _saved = true;
      if (mounted) {
        // Like the fill-up: a sheet that closes in silence read as a
        // save that may not have happened.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.serviceSaved)));
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

  /// Deleting goes through the same busy/failure path as saving: a delete the
  /// server rejects has to say so in the sheet, not throw out of the button's
  /// callback where nothing is listening.
  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      await ref
          .read(maintenanceRepositoryProvider)
          .deleteServiceEntry(widget.existing!.id);
      ref
        ..invalidate(serviceEntriesProvider(_vehicleId))
        ..invalidate(vehicleProjectionsProvider(_vehicleId));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final level = ref.watch(trackingLevelProvider);
    // A visit logged twice — a save retried after a timeout, or a second tap
    // on a slow button — leaves two rows nothing distinguishes, and the
    // service history they describe says the oil was changed twice at the
    // same odometer on the same day.
    final odometerTyped = _parse(_odometer.text);
    final duplicate =
        odometerTyped != null &&
        duplicatesExistingService(
          existing:
              ref.watch(serviceEntriesProvider(_vehicleId)).value ??
              const <ServiceEntry>[],
          editingId: widget.existing?.id,
          date: DateTime.utc(_date.year, _date.month, _date.day),
          odometerKm: prefs.displayToKm(odometerTyped).round(),
          serviceTypeKeys: _selectedKeys.toList(growable: false),
        );

    final catalogue = ref.watch(availableServiceTypesProvider(_vehicleId));
    final types = catalogue.value ?? const <ServiceType>[];
    // A failed fetch — of the catalogue, the household or the vehicle — used
    // to render as an empty chip row, which reads as "this car has no
    // services to log" rather than as a fetch that did not happen.
    final catalogueFailure = catalogue.hasValue
        ? null
        : catalogue.error == null
        ? null
        : failureMessage(l10n, AppFailure.from(catalogue.error!));
    // A selected key the fuel filter hides (an oil change logged on a car
    // recorded as electric) still needs a chip, or it can never be
    // deselected and rides along silently on every save.
    final offered = [
      ...types,
      for (final key in _selectedKeys)
        if (!types.any((t) => t.key == key)) ServiceType(key: key),
    ];
    // Paperwork (registration, insurance, a vignette) is paid, not done: the
    // cost sheet owns it and sets its reminder. Thirty chips in one weight
    // with Insurance beside Oil change was a wall; the common jobs lead.
    //
    // Except where a reminder is standing for it. The cost sheet settles only
    // what a cost category maps, and only for a one-off rule: a technical
    // inspection has no category at all, and a yearly registration rule
    // resets on a service entry carrying its key. Hiding those chips left
    // reminders nothing in the app could ever complete.
    final standing = {
      for (final rule
          in ref.watch(reminderRulesProvider(_vehicleId)).value ??
              const <ReminderRule>[])
        if (rule.active) rule.serviceTypeKey,
    };
    final work = [
      for (final type in offered)
        if (!paperworkServiceTypes.contains(type.key) ||
            _keptStatutory.contains(type.key) ||
            standing.contains(type.key))
          type,
    ];
    final sortedTypes = [
      for (final key in commonServiceTypes)
        for (final type in work)
          if (type.key == key) type,
      ...([
        for (final type in work)
          if (!commonServiceTypes.contains(type.key)) type,
      ]..sort(
        (a, b) => serviceTypeLabel(
          l10n,
          a.key,
        ).compareTo(serviceTypeLabel(l10n, b.key)),
      )),
    ];

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
                controllers: [
                  _odometer,
                  _cost,
                  _shop,
                  _notes,
                  _partsCost,
                  _laborCost,
                  _partsDetail,
                  _faultCodes,
                  ..._readings.values,
                ],
              ),
              Text(
                widget.existing == null
                    ? l10n.maintenanceLogService
                    : l10n.maintenanceEditService,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SheetVehicleRow(
                vehicleId: _vehicleId,
                // Locked once a receipt is on it; see the fill-up sheet.
                onSwitch: widget.existing == null && !_attachedAny
                    ? _switchVehicle
                    : null,
                lockedNote: widget.existing == null && _attachedAny
                    ? l10n.sheetVehicleLockedByFile
                    : null,
              ),
              const SizedBox(height: GarageTokens.space2),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.maintenanceServiceDate),
                subtitle: Text(format.formatShortDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              LabeledField(
                label: l10n.fuelOdometer,
                child: TextField(
                  // Keyed like every other sheet's numeric field: a test that
                  // finds the box by position finds a different one the
                  // moment a field is added above it.
                  key: const Key('service-odometer'),
                  controller: _odometer,
                  keyboardType: TextInputType.number,
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixText: format.distanceSuffix,
                    errorText: _odometerMissing
                        ? l10n.fuelOdometerRequired
                        : null,
                  ),
                  onChanged: (_) => setState(() => _odometerMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.maintenanceServiceCost,
                child: TextField(
                  controller: _cost,
                  focusNode: _costFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixText: format.currencySymbol,
                  ),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.maintenanceServiceShop,
                child: TextField(controller: _shop),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
              if (level.showsPartsAndLabour) ...[
                const SizedBox(height: GarageTokens.space3),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _diy,
                  onChanged: (value) => setState(() => _diy = value),
                  title: Text(l10n.serviceDiy),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LabeledField(
                            label: l10n.servicePartsCost,
                            child: TextField(
                              controller: _partsCost,
                              focusNode: _partsCostFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GarageTheme.numericField(context),
                              decoration: InputDecoration(
                                suffixText: format.currencySymbol,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: GarageTokens.space3),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LabeledField(
                            label: l10n.serviceLaborCost,
                            child: TextField(
                              controller: _laborCost,
                              focusNode: _laborCostFocus,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GarageTheme.numericField(context),
                              decoration: InputDecoration(
                                suffixText: format.currencySymbol,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.servicePartsDetail,
                  child: TextField(controller: _partsDetail),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.serviceWarrantyUntil),
                  subtitle: Text(
                    _warrantyUntil == null
                        ? UnitFormat.emptyValue
                        : format.formatShortDate(_warrantyUntil!),
                  ),
                  trailing: const Icon(Icons.shield_outlined),
                  onTap: _pickWarrantyDate,
                ),
              ],
              if (level.showsMeasurements) ...[
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.serviceFaultCodes,
                  child: TextField(
                    controller: _faultCodes,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      helperText: l10n.serviceFaultCodesHint,
                    ),
                  ),
                ),
                const SizedBox(height: GarageTokens.space4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.serviceMeasurements,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final measurement in Measurements.all)
                  LabeledField(
                    label:
                        '${_measurementLabel(l10n, measurement.key)} '
                        '(${measurement.unit})',
                    child: TextField(
                      controller: _reading(measurement.key),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GarageTheme.numericField(context),
                    ),
                  ),
              ],
              const SizedBox(height: GarageTokens.space4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.maintenanceServiceItems,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (catalogueFailure != null)
                Padding(
                  padding: const EdgeInsets.only(top: GarageTokens.space2),
                  child: Text(
                    catalogueFailure,
                    style: TextStyle(color: context.tokens.danger),
                  ),
                ),
              Wrap(
                spacing: GarageTokens.space2,
                children: [
                  for (final type in sortedTypes)
                    FilterChip(
                      label: Text(serviceTypeLabel(l10n, type.key)),
                      selected: _selectedKeys.contains(type.key),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedKeys.add(type.key);
                          // Kept offered from here on. A paperwork chip is
                          // shown because a reminder asks for it; if that
                          // reminder is completed elsewhere while this sheet
                          // is open, the chip would otherwise vanish with the
                          // key still ticked — unremovable and invisible.
                          _keptStatutory.add(type.key);
                        } else {
                          _selectedKeys.remove(type.key);
                        }
                      }),
                    ),
                ],
              ),
              // A warning, not a refusal: a job genuinely done twice in a day
              // happens — a leak found after the first attempt — and the
              // household is the one who knows which this is.
              if (duplicate) ...[
                const SizedBox(height: GarageTokens.space2),
                Text(
                  l10n.serviceDuplicateWarning,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              if (_selectionError != null) ...[
                const SizedBox(height: GarageTokens.space2),
                Text(
                  _selectionError!,
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              if (_failure != null) ...[
                const SizedBox(height: GarageTokens.space3),
                Text(
                  // The entry is not lost, which is the first thing a person
                  // whose save failed wants to know.
                  '${failureMessage(l10n, _failure!)} ${l10n.saveEntryKept}',
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space4),
              // Offered while the entry is still being typed: the id
              // exists before the row does, and anything attached to a
              // sheet that is then abandoned is taken back down.
              EntryAttachments(
                vehicleId: _vehicleId,
                kind: AttachmentEntryKind.service,
                entryId: widget.existing?.id ?? _newId,
                onUpload: (upload) {
                  _uploads.add(upload);
                  setState(() => _attachedAny = true);
                },
              ),
              const SizedBox(height: GarageTokens.space5),
              AmountCalculatorDock(
                fields: [
                  AmountField(_cost, _costFocus),
                  AmountField(_partsCost, _partsCostFocus),
                  AmountField(_laborCost, _laborCostFocus),
                ],
                format: format,
              ),
              const SizedBox(height: GarageTokens.space2),
              FilledButton(
                onPressed: _busy ? null : () => _submit(prefs),
                child: BusyLabel(busy: _busy, child: Text(l10n.commonSave)),
              ),
              StillSavingNote(busy: _busy),
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

/// The label for a reading. Keys are language-neutral; this is where they
/// become words.
String _measurementLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'brake_pad_front_mm' => l10n.measurementBrakePadFront,
    'brake_pad_rear_mm' => l10n.measurementBrakePadRear,
    'brake_disc_front_mm' => l10n.measurementBrakeDiscFront,
    'tread_front_left_mm' => l10n.measurementTreadFrontLeft,
    'tread_front_right_mm' => l10n.measurementTreadFrontRight,
    'tread_rear_left_mm' => l10n.measurementTreadRearLeft,
    'tread_rear_right_mm' => l10n.measurementTreadRearRight,
    'battery_volts' => l10n.measurementBatteryVolts,
    'battery_cca' => l10n.measurementBatteryCca,
    _ => key,
  };
}
