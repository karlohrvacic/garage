import '../../../core/widgets/unit_suffix.dart';
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
import '../../../domain/entities/odometer_entry.dart';
import '../../../domain/odometer/odometer_jump.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/odometer_providers.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../core/ids.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';

/// Opens the odometer sheet and returns true if a reading was saved.
Future<bool?> showOdometerEntrySheet(
  BuildContext context,
  String vehicleId, {
  OdometerEntry? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => OdometerEntrySheet(vehicleId: vehicleId, existing: existing),
  );
}

/// The shortest entry form in the app on purpose: a date and a number.
///
/// Anything else asked for here would defeat the point, which is to give
/// somebody who pays cash at the pump a way to tell the app how far the car
/// has gone without inventing a fill-up they did not make.
class OdometerEntrySheet extends ConsumerStatefulWidget {
  const OdometerEntrySheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final OdometerEntry? existing;

  @override
  ConsumerState<OdometerEntrySheet> createState() => _OdometerEntrySheetState();
}

class _OdometerEntrySheetState extends ConsumerState<OdometerEntrySheet> {
  /// Chosen once, so a save retried after a timeout is the same entry.
  late final _newId = newEntryId();
  final _reading = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  bool _busy = false;
  bool _readingMissing = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    _date = existing.date.toLocal();
    _notes.text = existing.notes ?? '';
    _reading.text = ref
        .read(unitPreferencesProvider)
        .kmToDisplay(existing.odometerKm.toDouble())
        .round()
        .toString();
  }

  @override
  void dispose() {
    _reading.dispose();
    _notes.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    setState(() {
      _readingMissing = false;
      _failure = null;
    });

    final typed = double.tryParse(_reading.text.trim().replaceAll(',', '.'));
    if (typed == null || typed < 0) {
      setState(() => _readingMissing = true);
      return;
    }
    // Typed in whatever the household reads its dashboard in; stored in
    // kilometres like every other distance.
    final km = ref.read(unitPreferencesProvider).displayToKm(typed).round();

    setState(() => _busy = true);

    final entry = OdometerEntry(
      id: widget.existing?.id ?? _newId,
      vehicleId: widget.vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      odometerKm: km,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
    );

    try {
      final repository = ref.read(odometerRepositoryProvider);
      if (widget.existing == null) {
        await writeNew(() => repository.add(entry));
      } else {
        await writeWithTimeout(repository.update(entry));
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

  /// What the field says, in kilometres, or null while it is unreadable.
  int? _typedKm() {
    final typed = double.tryParse(_reading.text.trim().replaceAll(',', '.'));
    if (typed == null || typed < 0) {
      return null;
    }
    return ref.read(unitPreferencesProvider).displayToKm(typed).round();
  }

  /// The newest reading this car has before the day being typed.
  ///
  /// Not simply the latest: an entry can be dated into the past, and the
  /// reading it should be compared against is the one it follows, not the
  /// one at the top of the list. The entry being edited is skipped, or it
  /// would be compared against itself.
  OdometerEntry? _previousReading() {
    final entries =
        ref.watch(odometerEntriesProvider(widget.vehicleId)).value ??
        const <OdometerEntry>[];
    final on = DateTime.utc(_date.year, _date.month, _date.day);
    OdometerEntry? best;
    for (final entry in entries) {
      if (entry.id == widget.existing?.id) {
        continue;
      }
      if (entry.date.isAfter(on)) {
        continue;
      }
      if (best == null || entry.date.isAfter(best.date)) {
        best = entry;
      }
    }
    return best;
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
      await ref.read(odometerRepositoryProvider).delete(widget.existing!.id);
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

  /// A reading changes where the car stands, which is what every distance-based
  /// projection is measured against — so the projections have to be recomputed,
  /// not only the list this came from.
  void _invalidate() {
    ref
      ..invalidate(odometerEntriesProvider(widget.vehicleId))
      ..invalidate(vehicleProjectionsProvider(widget.vehicleId));
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
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DiscardGuard(controllers: [_reading, _notes]),
              Text(
                widget.existing == null ? l10n.odometerAdd : l10n.odometerEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space2),
              Text(
                l10n.odometerHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
              ),
              const SizedBox(height: GarageTokens.space4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.costDate),
                subtitle: Text(format.formatShortDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              LabeledField(
                label: l10n.odometerReading,
                child: TextField(
                  key: const Key('odometer-reading'),
                  controller: _reading,
                  keyboardType: TextInputType.number,
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixIcon: unitSuffix(context, format.distanceSuffix),
                    errorText: _readingMissing
                        ? l10n.fuelOdometerRequired
                        : null,
                    // A warning, not a refusal, like every other check at the
                    // moment of entry: a car really can be driven onto a
                    // transporter and unloaded a thousand kilometres away.
                    helperText: switch (_previousReading()) {
                      final previous?
                          when isImplausibleJump(
                            fromKm: previous.odometerKm,
                            fromDate: previous.date,
                            toKm: _typedKm() ?? 0,
                            toDate: DateTime.utc(
                              _date.year,
                              _date.month,
                              _date.day,
                            ),
                          ) =>
                        l10n.odometerJumpWarning(
                          format.formatDistance(
                            ((_typedKm() ?? 0) - previous.odometerKm)
                                .toDouble(),
                            decimals: 0,
                          ),
                          format.formatShortDate(previous.date.toLocal()),
                        ),
                      _ => null,
                    },
                    helperMaxLines: 2,
                    helperStyle: TextStyle(color: context.tokens.danger),
                  ),
                  onChanged: (_) => setState(() => _readingMissing = false),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.fuelNotes,
                child: TextField(controller: _notes),
              ),
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
                onPressed: _busy ? null : _submit,
                child: Text(l10n.commonSave),
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
