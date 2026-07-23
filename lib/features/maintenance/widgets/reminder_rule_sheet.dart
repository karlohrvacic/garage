import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/entities/reminder_rule.dart';
import '../data/maintenance_repository.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';

Future<bool?> showReminderRuleSheet(BuildContext context, String vehicleId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReminderRuleSheet(vehicleId: vehicleId),
  );
}

class ReminderRuleSheet extends ConsumerStatefulWidget {
  const ReminderRuleSheet({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<ReminderRuleSheet> createState() => _ReminderRuleSheetState();
}

class _ReminderRuleSheetState extends ConsumerState<ReminderRuleSheet> {
  final _km = TextEditingController();
  final _months = TextEditingController();

  String? _serviceTypeKey;
  bool _busy = false;
  String? _intervalError;
  AppFailure? _failure;

  @override
  void dispose() {
    _km.dispose();
    _months.dispose();
    super.dispose();
  }

  void _applyDefaults(ServiceType type) {
    _km.text = type.defaultIntervalKm?.toString() ?? '';
    _months.text = type.defaultIntervalMonths?.toString() ?? '';
  }

  Future<void> _submit() async {
    final key = _serviceTypeKey;
    if (key == null) {
      return;
    }
    final km = int.tryParse(_km.text.trim());
    final months = int.tryParse(_months.text.trim());
    final l10n = AppLocalizations.of(context)!;
    if (km == null && months == null) {
      setState(() => _intervalError = l10n.maintenanceNeedsInterval);
      return;
    }

    setState(() {
      _busy = true;
      _intervalError = null;
      _failure = null;
    });

    try {
      await ref.read(maintenanceRepositoryProvider).upsertRule(
            ReminderRule(
              id: '',
              vehicleId: widget.vehicleId,
              serviceTypeKey: key,
              intervalKm: km,
              intervalMonths: months,
            ),
          );
      ref.invalidate(reminderRulesProvider(widget.vehicleId));
      ref.invalidate(vehicleProjectionsProvider(widget.vehicleId));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _failure = AppFailure.from(error);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final types = ref.watch(serviceTypesProvider).value ?? const <ServiceType>[];
    final sortedTypes = [...types]
      ..sort(
        (a, b) => serviceTypeLabel(l10n, a.key)
            .compareTo(serviceTypeLabel(l10n, b.key)),
      );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              DropdownButtonFormField<String>(
                initialValue: _serviceTypeKey,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: l10n.maintenanceRuleServiceType),
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
              const SizedBox(height: GarageTokens.space4),
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.maintenanceIntervalKm),
              ),
              const SizedBox(height: GarageTokens.space3),
              TextField(
                controller: _months,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.maintenanceIntervalMonths),
              ),
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
