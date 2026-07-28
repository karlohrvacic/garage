import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/cost_entry.dart';
import '../../settings/providers/unit_providers.dart';
import '../cost_category_labels.dart';
import '../providers/cost_providers.dart';

/// Opens the cost-entry sheet and returns true if an entry was saved.
Future<bool?> showCostEntrySheet(
  BuildContext context,
  String vehicleId, {
  CostEntry? existing,
}) {
  return showAdaptiveEntrySheet<bool>(
    context,
    (_) => CostEntrySheet(vehicleId: vehicleId, existing: existing),
  );
}

class CostEntrySheet extends ConsumerStatefulWidget {
  const CostEntrySheet({required this.vehicleId, this.existing, super.key});

  final String vehicleId;
  final CostEntry? existing;

  @override
  ConsumerState<CostEntrySheet> createState() => _CostEntrySheetState();
}

class _CostEntrySheetState extends ConsumerState<CostEntrySheet> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  String _category = CostCategories.registration;
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

  double? _parseAmount() {
    final normalized = _amount.text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    setState(() {
      _amountMissing = false;
      _failure = null;
    });

    final amount = _parseAmount();
    if (amount == null || amount < 0) {
      setState(() => _amountMissing = true);
      return;
    }

    setState(() => _busy = true);

    final entry = CostEntry(
      id: widget.existing?.id ?? '',
      vehicleId: widget.vehicleId,
      date: DateTime.utc(_date.year, _date.month, _date.day),
      category: _category,
      amount: amount,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdBy: widget.existing?.createdBy ?? '',
    );

    try {
      if (widget.existing == null) {
        await ref.read(costRepositoryProvider).add(entry);
      } else {
        await ref.read(costRepositoryProvider).update(entry);
      }
      ref.invalidate(costEntriesProvider(widget.vehicleId));
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
              Text(l10n.costAdd, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: GarageTokens.space4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.costDate),
                subtitle: Text(format.formatShortDate(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              LabeledField(
                label: l10n.costCategory,
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  items: [
                    for (final key in CostCategories.all)
                      DropdownMenuItem(
                        value: key,
                        child: Text(costCategoryLabel(l10n, key)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
              ),
              const SizedBox(height: GarageTokens.space3),
              LabeledField(
                label: l10n.costAmount,
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GarageTheme.numericField(context),
                  decoration: InputDecoration(
                    errorText: _amountMissing ? l10n.costAmountRequired : null,
                  ),
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
                  failureMessage(l10n, _failure!),
                  style: TextStyle(color: context.tokens.danger),
                ),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
