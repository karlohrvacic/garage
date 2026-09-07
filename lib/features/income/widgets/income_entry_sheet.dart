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
import '../../../core/widgets/busy_label.dart';
import '../../../domain/entities/income_entry.dart';
import '../../../domain/format/amount_expression.dart';
import '../../settings/providers/unit_providers.dart';
import '../income_category_labels.dart';
import '../providers/income_providers.dart';
import '../../../core/widgets/save_progress.dart';
import '../../../core/ids.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/amount_calculator_dock.dart';

/// Opens the income sheet and returns true if an entry was saved.
Future<bool?> showIncomeEntrySheet(
  BuildContext context,
  String vehicleId, {
  IncomeEntry? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => IncomeEntrySheet(vehicleId: vehicleId, existing: existing),
  );
}

class IncomeEntrySheet extends ConsumerStatefulWidget {
  const IncomeEntrySheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final IncomeEntry? existing;

  @override
  ConsumerState<IncomeEntrySheet> createState() => _IncomeEntrySheetState();
}

class _IncomeEntrySheetState extends ConsumerState<IncomeEntrySheet> {
  /// Chosen once, so a save retried after a timeout is the same entry.
  late final _newId = newEntryId();
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  String _category = IncomeCategories.ride;
  bool _busy = false;
  bool _amountMissing = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      return;
    }
    _date = existing.date.toLocal();
    _category = existing.category;
    _amount.text = existing.amount.toStringAsFixed(2);
    _notes.text = existing.notes ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
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
      _amountMissing = false;
      _failure = null;
    });

    final amount = evaluateAmount(_amount.text);
    if (amount == null || amount < 0) {
      setState(() => _amountMissing = true);
      return;
    }

    setState(() => _busy = true);

    final entry = IncomeEntry(
      id: widget.existing?.id ?? _newId,
      vehicleId: widget.vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      category: _category,
      amount: amount,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
    );

    try {
      final repository = ref.read(incomeRepositoryProvider);
      if (widget.existing == null) {
        await writeNew(() => repository.add(entry));
      } else {
        await writeWithTimeout(repository.update(entry));
      }
      ref.invalidate(incomeEntriesProvider(widget.vehicleId));
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
      await ref.read(incomeRepositoryProvider).delete(widget.existing!.id);
      ref.invalidate(incomeEntriesProvider(widget.vehicleId));
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
              DiscardGuard(controllers: [_amount, _notes]),
              Text(
                widget.existing == null ? l10n.incomeAdd : l10n.incomeEdit,
                style: Theme.of(context).textTheme.titleLarge,
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
                label: l10n.incomeCategory,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  items: [
                    for (final key in IncomeCategories.all)
                      DropdownMenuItem(
                        value: key,
                        child: Text(incomeCategoryLabel(l10n, key)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.incomeAmount,
                child: TextField(
                  key: const Key('income-amount'),
                  controller: _amount,
                  focusNode: _amountFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    suffixIcon: unitSuffix(context, format.currencySymbol),
                    errorText: _amountMissing ? l10n.costAmountRequired : null,
                  ),
                  onChanged: (_) => setState(() => _amountMissing = false),
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
              AmountCalculatorDock(
                fields: [AmountField(_amount, _amountFocus)],
                format: format,
              ),
              const SizedBox(height: GarageTokens.space2),
              FilledButton(
                onPressed: _busy ? null : _submit,
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
