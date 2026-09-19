import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../domain/entities/vehicle.dart';
import '../../../domain/entities/vehicle_assignment.dart';
import '../../household/data/household_repository.dart';
import '../../household/providers/member_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/company_providers.dart';

/// Who gets the car next, from when, and what the odometer said.
///
/// One call closes the current window, writes the reading and opens the
/// next (`hand_over_vehicle`, migration 0080), so the log and the odometer
/// series cannot disagree. "Nobody" takes the car back, which a lapsed plan
/// still allows.
Future<void> showHandoverSheet(
  BuildContext context, {
  required Vehicle vehicle,
  VehicleAssignment? current,
}) {
  return showAdaptiveEntrySheet<void>(
    context,
    (sheetContext) => _HandoverForm(vehicle: vehicle, current: current),
  );
}

class _HandoverForm extends ConsumerStatefulWidget {
  const _HandoverForm({required this.vehicle, this.current});

  final Vehicle vehicle;
  final VehicleAssignment? current;

  @override
  ConsumerState<_HandoverForm> createState() => _HandoverFormState();
}

class _HandoverFormState extends ConsumerState<_HandoverForm> {
  String? _toUserId;
  late DateTime _on;
  late final DateTime _openedOn;
  final _odometer = TextEditingController();
  final _note = TextEditingController();

  /// Whether the reading was filled in from the car's own, so a value the
  /// person typed is never replaced by one that arrived later.
  bool _prefilled = false;
  bool _busy = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _on = ref.read(todayProvider);
    _openedOn = _on;
    // Where the car stands, in the garage's unit: a handover is read off the
    // dashboard at the moment the keys change hands, and the number is
    // usually the one already known. Nothing else on the console watches
    // the car's odometer, so the value is more often on its way than here;
    // `build` listens for it.
    _prefill(ref.read(currentOdometerProvider(widget.vehicle.id)).value);
  }

  void _prefill(int? km) {
    if (_prefilled || km == null || _odometer.text.isNotEmpty) {
      return;
    }
    _prefilled = true;
    final prefs = ref.read(unitPreferencesProvider);
    _odometer.text = prefs.kmToDisplay(km.toDouble()).round().toString();
  }

  @override
  void dispose() {
    _odometer.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      currentOdometerProvider(widget.vehicle.id),
      (_, next) => _prefill(next.value),
    );
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.watch(unitPreferencesProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: prefs,
    );
    final enabled = ref.watch(companyEnabledProvider);
    final members = ref.watch(membersProvider);
    // A member list that failed to load before anything arrived is said,
    // not shown as nobody to hand the car to: "invite someone" would be the
    // wrong instruction, and the cause has to reach the failure log.
    final membersFailure = !members.hasValue && members.hasError
        ? failureMessage(l10n, AppFailure.from(members.error!))
        : null;
    // Anybody in the garage but whoever has it now. Drivers first: they are
    // what the list is for, and an admin taking a van for a day is the rare
    // case.
    final candidates =
        [
          for (final member in members.value ?? const <HouseholdMember>[])
            if (member.userId != widget.current?.userId) member,
        ]..sort((a, b) {
          final byRole =
              (a.role == 'driver' ? 0 : 1) - (b.role == 'driver' ? 0 : 1);
          return byRole != 0 ? byRole : a.displayName.compareTo(b.displayName);
        });

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
              controllers: [_odometer, _note],
              alsoDirty: () => _toUserId != null || _on != _openedOn,
            ),
            Text(
              l10n.companyHandOverTitle(widget.vehicle.nickname),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: GarageTokens.space5),
            LabeledField(
              label: l10n.companyHandOverTo,
              child: DropdownButtonFormField<String?>(
                key: const Key('handover-to'),
                initialValue: _toUserId,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.companyHandOverNobody),
                  ),
                  // Handing on waits for the plan; taking back does not.
                  if (enabled)
                    for (final member in candidates)
                      DropdownMenuItem<String?>(
                        value: member.userId,
                        child: Text(member.displayName),
                      ),
                ],
                onChanged: (value) => setState(() => _toUserId = value),
              ),
            ),
            if (enabled && membersFailure != null) ...[
              const SizedBox(height: GarageTokens.space2),
              Text(
                membersFailure,
                style: TextStyle(color: context.tokens.danger),
              ),
            ] else if (enabled && !members.hasValue) ...[
              const SizedBox(height: GarageTokens.space2),
              const Center(
                child: SizedBox(
                  width: GarageTokens.space5,
                  height: GarageTokens.space5,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (enabled && candidates.isEmpty) ...[
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.companyHandOverNoDrivers,
                style: TextStyle(color: context.tokens.muted),
              ),
            ],
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.companyHandOverOn,
              child: OutlinedButton(
                key: const Key('handover-date'),
                onPressed: _pickDate,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(format.formatDate(_on)),
                ),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.companyHandOverOdometer,
              child: TextField(
                key: const Key('handover-odometer'),
                controller: _odometer,
                keyboardType: TextInputType.number,
                style: GarageTheme.numericField(context),
                decoration: InputDecoration(suffixText: format.distanceSuffix),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.companyHandOverNote,
              child: TextField(
                key: const Key('handover-note'),
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
              ),
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
              key: const Key('handover-save'),
              onPressed: _busy ? null : _save,
              child: Text(l10n.companyHandOver),
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
      initialDate: _on,
      firstDate: firstLoggableDate(_on),
      // Ahead is allowed: a handover is often arranged for Monday on Friday.
      lastDate: _openedOn.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _on = picked);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = ref.read(unitPreferencesProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final typed = double.tryParse(_odometer.text.trim().replaceAll(',', '.'));
    setState(() {
      _busy = true;
      _failure = null;
    });

    final ok = await ref
        .read(companyControllerProvider.notifier)
        .handOver(
          vehicleId: widget.vehicle.id,
          on: DateTime(_on.year, _on.month, _on.day),
          odometerKm: typed == null ? null : prefs.displayToKm(typed).round(),
          toUserId: _toUserId,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) {
      return;
    }
    if (!ok) {
      setState(() {
        _busy = false;
        _failure = failureOf(ref.read(companyControllerProvider));
      });
      return;
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.companyHandedOver)));
  }
}
