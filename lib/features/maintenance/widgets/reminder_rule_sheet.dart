import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_log.dart';
import '../../../core/format/unit_format.dart';
import '../../settings/providers/unit_providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/busy_label.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/maintenance/interval_defaults.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../vehicles/widgets/sheet_vehicle_row.dart';
import 'service_type_field.dart'
    show ServiceTypeField, offeredReminderTypes, oneOffServiceTypes;
import '../data/maintenance_repository.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/ids.dart';

Future<bool?> showReminderRuleSheet(
  BuildContext context,
  String vehicleId, {
  ReminderRule? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => ReminderRuleSheet(vehicleId: vehicleId, existing: existing),
  );
}

class ReminderRuleSheet extends ConsumerStatefulWidget {
  const ReminderRuleSheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final ReminderRule? existing;

  @override
  ConsumerState<ReminderRuleSheet> createState() => _ReminderRuleSheetState();
}

class _ReminderRuleSheetState extends ConsumerState<ReminderRuleSheet> {
  /// The vehicle the rule is for; a new rule can be moved to another car
  /// from the first row, and its defaults then come from that car.
  late String _vehicleId = widget.vehicleId;

  /// For the "last done" service this sheet may log: chosen once, so a save
  /// retried after a timeout is the same row.
  late final _doneEntryId = newEntryId();
  late final _newRuleId = newEntryId();
  final _km = TextEditingController();
  final _months = TextEditingController();

  String? _serviceTypeKey;
  bool _oneTime = false;
  DateTime? _dueDate;
  final _dueKm = TextEditingController();
  bool _busy = false;
  String? _intervalError;
  AppFailure? _failure;

  /// What to say under the interval fields about the prefilled numbers.
  /// Cleared when the person edits either field: a remark about a default
  /// that is no longer in the box would be a claim about their number.
  IntervalDefault? _applied;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    _serviceTypeKey = existing.serviceTypeKey;
    _km.text = _kmText(existing.intervalKm);
    _months.text = existing.intervalMonths?.toString() ?? '';
    _oneTime = existing.oneTime;
    _dueDate = existing.dueDate?.toLocal();
    _dueKm.text = _kmText(existing.dueOdometerKm);
  }

  /// The km fields are in the household's distance unit, like every other
  /// odometer box in the app; storage stays canonical. Without this the
  /// fields showed and stored kilometres whatever the household read, which
  /// the "mi" suffix beside them made a visible lie.
  String _kmText(int? km) {
    if (km == null) {
      return '';
    }
    final prefs = ref.read(unitPreferencesProvider);
    return prefs.kmToDisplay(km.toDouble()).round().toString();
  }

  int? _kmFrom(TextEditingController field) {
    final typed = int.tryParse(field.text.trim());
    if (typed == null) {
      return null;
    }
    final prefs = ref.read(unitPreferencesProvider);
    return prefs.displayToKm(typed.toDouble()).round();
  }

  @override
  void dispose() {
    _km.dispose();
    _months.dispose();
    _dueKm.dispose();
    super.dispose();
  }

  /// A new rule moved to another car. A type the new car cannot have (chain
  /// lube on a hatchback) is dropped; untouched defaults are worked out again
  /// for the new make, since 30 000 km was the first car's answer, not a
  /// number anyone typed; typed values stay.
  Future<void> _switchVehicle(String id) async {
    setState(() => _vehicleId = id);
    final List<ServiceType> types;
    try {
      types = await ref.read(availableServiceTypesProvider(id).future);
    } on Object catch (error) {
      // The picker shows the failure when opened; here the type is simply
      // left as it was rather than surfacing an unhandled error.
      reportFailure(AppFailure.from(error));
      return;
    }
    if (!mounted || _vehicleId != id) {
      return;
    }
    final key = _serviceTypeKey;
    if (key == null) {
      return;
    }
    final type = types
        .where((t) => t.key == key && !oneOffServiceTypes.contains(t.key))
        .firstOrNull;
    if (type == null) {
      setState(() {
        _serviceTypeKey = null;
        _applied = null;
      });
      return;
    }
    if (_applied == null) {
      return;
    }
    await ref.read(vehicleProvider(id).future);
    if (!mounted || _vehicleId != id) {
      return;
    }
    _applyDefaults(type);
  }

  /// The most recent service of [key] on this vehicle, put into the
  /// "last done" fields.
  ///
  /// The sheet showed the interval it had worked out and then asked for a
  /// date the app already knew: the Reminders tab prints "Previously: Aug 10
  /// · 120,400 km" two rows below.
  Future<void> _prefillLastDone(String key) async {
    if (widget.existing != null || _doneDate != null) {
      return;
    }
    final List<ServiceEntry> entries;
    try {
      entries = await ref.read(serviceEntriesProvider(_vehicleId).future);
    } on Object catch (error) {
      reportFailure(AppFailure.from(error));
      return;
    }
    if (!mounted || _doneDate != null) {
      return;
    }
    final match = entries
        .where((entry) => entry.serviceTypeKeys.contains(key))
        .firstOrNull;
    if (match == null) {
      return;
    }
    final prefs = ref.read(unitPreferencesProvider);
    setState(() {
      _doneDate = match.date.toLocal();
      _doneKm.text = match.odometerKm == 0
          ? ''
          : prefs.kmToDisplay(match.odometerKm.toDouble()).round().toString();
      _lastDoneFromLog = match.date.toLocal();
    });
  }

  /// Set when the fields above were filled from a logged service, so the
  /// sheet can say where the numbers came from.
  DateTime? _lastDoneFromLog;

  void _applyDefaults(ServiceType type) {
    final vehicle = ref.read(vehicleProvider(_vehicleId)).value;
    final resolved = vehicle == null
        ? IntervalDefault(
            km: type.defaultIntervalKm,
            months: type.defaultIntervalMonths,
            source: IntervalSource.generic,
          )
        : IntervalDefaults.resolve(
            serviceTypeKey: type.key,
            presetKm: type.defaultIntervalKm,
            presetMonths: type.defaultIntervalMonths,
            vehicle: vehicle,
          );
    _km.text = _kmText(resolved.km);
    _months.text = resolved.months?.toString() ?? '';
    setState(() => _applied = resolved);
  }

  String? _defaultNote(AppLocalizations l10n, Vehicle? vehicle) {
    final applied = _applied;
    if (applied == null) {
      return null;
    }
    return switch (applied.note) {
      IntervalNote.chain => l10n.intervalNoteChain,
      IntervalNote.wetBelt => l10n.intervalNoteWetBelt,
      IntervalNote.setTimingDrive => l10n.intervalNoteSetTimingDrive,
      IntervalNote.setTransmission => l10n.intervalNoteSetTransmission,
      IntervalNote.sealed => l10n.intervalNoteSealed,
      IntervalNote.advisory => l10n.intervalNoteAdvisory,
      null =>
        applied.source == IntervalSource.make && vehicle?.make != null
            ? l10n.intervalNoteMake(vehicle!.make!)
            : null,
    };
  }

  /// What the user says they already did, logged as a service entry rather
  /// than stored on the rule. Projections read history, so an anchor kept on
  /// the rule would be a second version of the truth that can contradict it.
  final _doneKm = TextEditingController();
  DateTime? _doneDate;

  Future<void> _submit() async {
    final key = _serviceTypeKey;
    if (key == null) {
      return;
    }
    final km = _kmFrom(_km);
    final months = int.tryParse(_months.text.trim());
    final dueKm = _kmFrom(_dueKm);
    final l10n = AppLocalizations.of(context)!;
    if (_oneTime) {
      if (_dueDate == null && dueKm == null) {
        setState(() => _intervalError = l10n.maintenanceOneTimeNeedsTarget);
        return;
      }
    } else if (km == null && months == null) {
      setState(() => _intervalError = l10n.maintenanceNeedsInterval);
      return;
    }

    setState(() {
      _busy = true;
      _intervalError = null;
      _failure = null;
    });

    final due = _dueDate;
    try {
      await writeWithTimeout(
        ref
            .read(maintenanceRepositoryProvider)
            .upsertRule(
              ReminderRule(
                // A one-time rule gets its id here, so a save retried after
                // a timeout is the same row; a recurring rule keeps the
                // server's, since its repository updates by type first.
                id: widget.existing?.id ?? (_oneTime ? _newRuleId : ''),
                vehicleId: _vehicleId,
                serviceTypeKey: key,
                intervalKm: _oneTime ? null : km,
                intervalMonths: _oneTime ? null : months,
                oneTime: _oneTime,
                dueDate: !_oneTime || due == null
                    ? null
                    : DateTime.utc(due.year, due.month, due.day),
                dueOdometerKm: _oneTime ? dueKm : null,
              ),
            ),
      );

      final doneKm = _kmFrom(_doneKm);
      if (doneKm != null || _doneDate != null) {
        await writeNew(
          () => ref
              .read(maintenanceRepositoryProvider)
              .addServiceEntry(
                ServiceEntry(
                  id: _doneEntryId,
                  vehicleId: _vehicleId,
                  date: _doneDate ?? DateTime.now().toUtc(),
                  odometerKm: doneKm ?? 0,
                  serviceTypeKeys: [key],
                  createdBy: '',
                ),
              ),
        );
      }
      ref.invalidate(reminderRulesProvider(_vehicleId));
      ref.invalidate(vehicleProjectionsProvider(_vehicleId));
      if (mounted) {
        // Said out loud: a rule a year out shows on no screen the sheet
        // returns to, and a silent close read as a failed save.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.maintenanceRuleSaved(serviceTypeLabel(l10n, key)),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      // Guarded like every sibling sheet: a save the user swiped away from
      // still lands here, and `setState` on a sheet that is gone throws out of
      // the catch that was meant to contain the failure.
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
    final vehicle = ref.watch(vehicleProvider(_vehicleId)).value;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    // A rule can sit on a type the fuel filter hides: a car recorded as
    // electric with an oil-change rule, or a fuel corrected after its rules
    // were made. The picker must still offer the rule's own type, or the
    // dropdown asserts and the rule cannot be edited at all.
    final existingKey = widget.existing?.serviceTypeKey;

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
              DiscardGuard(controllers: [_km, _months, _dueKm, _doneKm]),
              Text(
                l10n.maintenanceAddRule,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SheetVehicleRow(
                vehicleId: _vehicleId,
                onSwitch: widget.existing == null ? _switchVehicle : null,
              ),
              const SizedBox(height: GarageTokens.space2),
              LabeledField(
                label: l10n.maintenanceRuleServiceType,
                child: ServiceTypeField(
                  fieldKey: const Key('rule-service-type'),
                  selected: _serviceTypeKey,
                  vehicleId: _vehicleId,
                  existingKey: existingKey,
                  onChanged: (value) {
                    setState(() => _serviceTypeKey = value);
                    // From the live list, not the one this build saw: the
                    // picker may have shown types that landed after it.
                    final type = offeredReminderTypes(
                      ref
                              .read(availableServiceTypesProvider(_vehicleId))
                              .value ??
                          const [],
                      existingKey,
                    ).where((t) => t.key == value).firstOrNull;
                    if (type != null) {
                      _applyDefaults(type);
                    }
                    _prefillLastDone(value);
                  },
                ),
              ),
              const SizedBox(height: GarageTokens.space4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _oneTime,
                onChanged: (value) => setState(() => _oneTime = value),
                title: Text(l10n.maintenanceOneTime),
              ),
              if (_oneTime) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.maintenanceDueDateField),
                  subtitle: Text(
                    _dueDate == null
                        ? UnitFormat.emptyValue
                        : MaterialLocalizations.of(
                            context,
                          ).formatShortDate(_dueDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showGarageDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      // An overdue reminder's date is in the past, and a
                      // picker opening outside its own bounds asserts. Today
                      // is the floor for a new date, not for the one already
                      // on the rule.
                      firstDate: switch (_dueDate) {
                        final due? when due.isBefore(DateTime.now()) => due,
                        _ => DateTime.now(),
                      },
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) {
                      setState(() => _dueDate = picked);
                    }
                  },
                ),
                LabeledField(
                  label: l10n.maintenanceDueKmField,
                  child: TextField(
                    controller: _dueKm,
                    keyboardType: TextInputType.number,
                    style: GarageTheme.numericField(context),
                    decoration: InputDecoration(
                      suffixText: format.distanceSuffix,
                    ),
                  ),
                ),
              ] else ...[
                LabeledField(
                  label: l10n.maintenanceIntervalKm,
                  child: TextField(
                    controller: _km,
                    keyboardType: TextInputType.number,
                    style: GarageTheme.numericField(context),
                    decoration: InputDecoration(
                      suffixText: format.distanceSuffix,
                    ),
                    onChanged: (_) {
                      if (_applied != null) {
                        setState(() => _applied = null);
                      }
                    },
                  ),
                ),
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.maintenanceIntervalMonths,
                  child: TextField(
                    controller: _months,
                    keyboardType: TextInputType.number,
                    style: GarageTheme.numericField(context),
                    onChanged: (_) {
                      if (_applied != null) {
                        setState(() => _applied = null);
                      }
                    },
                  ),
                ),
                if (_defaultNote(l10n, vehicle) case final note?) ...[
                  const SizedBox(height: GarageTokens.space2),
                  Text(
                    note,
                    key: const Key('rule-default-note'),
                    style: TextStyle(color: context.tokens.muted),
                  ),
                ],
                const SizedBox(height: GarageTokens.space2),
                Text(
                  l10n.maintenanceIntervalHint,
                  style: TextStyle(color: context.tokens.muted),
                ),
                const SizedBox(height: GarageTokens.space5),
                // Without this an interval counted from the day the car was
                // added, so a rule for something serviced last month read as
                // long overdue. What is entered here is logged as the service
                // it was, which is what projections measure from.
                Text(
                  l10n.maintenanceLastDone.toUpperCase(),
                  style: GarageTheme.eyebrow(context),
                ),
                if (_lastDoneFromLog case final date?)
                  Padding(
                    padding: const EdgeInsets.only(top: GarageTokens.space1),
                    child: Text(
                      l10n.maintenanceLastDoneFromLog(
                        UnitFormat(
                          locale: Localizations.localeOf(context).languageCode,
                          preferences: ref.watch(unitPreferencesProvider),
                        ).formatShortDate(date),
                      ),
                      style: TextStyle(color: context.tokens.muted),
                    ),
                  ),
                const SizedBox(height: GarageTokens.space1),
                Text(
                  l10n.maintenanceLastDoneHint,
                  style: TextStyle(color: context.tokens.muted),
                ),
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.maintenanceLastDoneKm,
                  child: TextField(
                    key: const Key('rule-last-done-km'),
                    controller: _doneKm,
                    keyboardType: TextInputType.number,
                    style: GarageTheme.numericField(context),
                    decoration: InputDecoration(
                      suffixText: format.distanceSuffix,
                    ),
                  ),
                ),
                const SizedBox(height: GarageTokens.space3),
                ListTile(
                  key: const Key('rule-last-done-date'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.maintenanceLastDoneDate),
                  subtitle: Text(
                    _doneDate == null
                        ? l10n.maintenanceLastDoneDatePick
                        : UnitFormat(
                            locale: Localizations.localeOf(
                              context,
                            ).languageCode,
                            preferences: ref.watch(unitPreferencesProvider),
                          ).formatDate(_doneDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showGarageDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(
                        () => _doneDate = DateTime.utc(
                          picked.year,
                          picked.month,
                          picked.day,
                        ),
                      );
                    }
                  },
                ),
              ],
              if (_intervalError != null) ...[
                const SizedBox(height: GarageTokens.space2),
                Text(
                  _intervalError!,
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
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy || _serviceTypeKey == null ? null : _submit,
                child: BusyLabel(busy: _busy, child: Text(l10n.commonSave)),
              ),
              StillSavingNote(busy: _busy),
            ],
          ),
        ),
      ),
    );
  }
}
