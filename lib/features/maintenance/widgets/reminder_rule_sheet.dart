import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../settings/providers/unit_providers.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../../../domain/entities/service_entry.dart';
import '../data/maintenance_repository.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';

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
  final _km = TextEditingController();
  final _months = TextEditingController();

  String? _serviceTypeKey;
  bool _oneTime = false;
  DateTime? _dueDate;
  final _dueKm = TextEditingController();
  bool _busy = false;
  String? _intervalError;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    _serviceTypeKey = existing.serviceTypeKey;
    _km.text = existing.intervalKm?.toString() ?? '';
    _months.text = existing.intervalMonths?.toString() ?? '';
    _oneTime = existing.oneTime;
    _dueDate = existing.dueDate?.toLocal();
    _dueKm.text = existing.dueOdometerKm?.toString() ?? '';
  }

  @override
  void dispose() {
    _km.dispose();
    _months.dispose();
    _dueKm.dispose();
    super.dispose();
  }

  void _applyDefaults(ServiceType type) {
    _km.text = type.defaultIntervalKm?.toString() ?? '';
    _months.text = type.defaultIntervalMonths?.toString() ?? '';
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
    final km = int.tryParse(_km.text.trim());
    final months = int.tryParse(_months.text.trim());
    final dueKm = int.tryParse(_dueKm.text.trim());
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
      await ref
          .read(maintenanceRepositoryProvider)
          .upsertRule(
            ReminderRule(
              id: widget.existing?.id ?? '',
              vehicleId: widget.vehicleId,
              serviceTypeKey: key,
              intervalKm: _oneTime ? null : km,
              intervalMonths: _oneTime ? null : months,
              oneTime: _oneTime,
              dueDate: !_oneTime || due == null
                  ? null
                  : DateTime.utc(due.year, due.month, due.day),
              dueOdometerKm: _oneTime ? dueKm : null,
            ),
          );

      final doneKm = int.tryParse(_doneKm.text.trim());
      if (doneKm != null || _doneDate != null) {
        await ref
            .read(maintenanceRepositoryProvider)
            .addServiceEntry(
              ServiceEntry(
                id: '',
                vehicleId: widget.vehicleId,
                date: _doneDate ?? DateTime.now().toUtc(),
                odometerKm: doneKm ?? 0,
                serviceTypeKeys: [key],
                createdBy: '',
              ),
            );
      }
      ref.invalidate(reminderRulesProvider(widget.vehicleId));
      ref.invalidate(vehicleProjectionsProvider(widget.vehicleId));
      if (mounted) {
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
    final types =
        ref.watch(availableServiceTypesProvider).value ?? const <ServiceType>[];
    final sortedTypes = [...types]
      ..sort(
        (a, b) => serviceTypeLabel(
          l10n,
          a.key,
        ).compareTo(serviceTypeLabel(l10n, b.key)),
      );

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
              Text(
                l10n.maintenanceAddRule,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space4),
              LabeledField(
                label: l10n.maintenanceRuleServiceType,
                child: DropdownButtonFormField<String>(
                  initialValue: _serviceTypeKey,
                  isExpanded: true,
                  items: [
                    for (final type in sortedTypes)
                      DropdownMenuItem(
                        value: type.key,
                        child: Text(serviceTypeLabel(l10n, type.key)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _serviceTypeKey = value);
                    final type = types.firstWhere((t) => t.key == value);
                    _applyDefaults(type);
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
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
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
                  ),
                ),
              ] else ...[
                LabeledField(
                  label: l10n.maintenanceIntervalKm,
                  child: TextField(
                    controller: _km,
                    keyboardType: TextInputType.number,
                    style: GarageTheme.numericField(context),
                  ),
                ),
                const SizedBox(height: GarageTokens.space3),
                LabeledField(
                  label: l10n.maintenanceIntervalMonths,
                  child: TextField(
                    controller: _months,
                    keyboardType: TextInputType.number,
                    style: GarageTheme.numericField(context),
                  ),
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
                  ),
                ),
                const SizedBox(height: GarageTokens.space3),
                ListTile(
                  key: const Key('rule-last-done-date'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.maintenanceLastDoneDate),
                  subtitle: Text(
                    _doneDate == null
                        ? l10n.commonEmpty
                        : UnitFormat(
                            locale: Localizations.localeOf(
                              context,
                            ).languageCode,
                            preferences: ref.watch(unitPreferencesProvider),
                          ).formatDate(_doneDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
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
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.maintenanceIntervalHint,
                style: TextStyle(color: context.tokens.muted),
              ),
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
                  failureMessage(l10n, _failure!),
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy || _serviceTypeKey == null ? null : _submit,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
