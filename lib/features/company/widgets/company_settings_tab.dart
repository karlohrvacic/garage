import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/company_providers.dart';

/// The letterhead, and where the plan stands. The plan itself is not a
/// setting: billing writes it, and the column privilege refuses everybody
/// else.
class CompanySettingsTab extends ConsumerStatefulWidget {
  const CompanySettingsTab({super.key});

  @override
  ConsumerState<CompanySettingsTab> createState() => _CompanySettingsTabState();
}

class _CompanySettingsTabState extends ConsumerState<CompanySettingsTab> {
  late final TextEditingController _name;
  late final TextEditingController _oib;
  late final TextEditingController _address;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final household = ref.read(currentHouseholdProvider).value;
    _name = TextEditingController(text: household?.companyName ?? '');
    _oib = TextEditingController(text: household?.companyOib ?? '');
    _address = TextEditingController(text: household?.companyAddress ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _oib.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(currentHouseholdProvider).value;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final until = household?.planUntil;
    final plan = until == null
        ? l10n.companyPlanActive
        : ref.watch(companyEnabledProvider)
        ? l10n.companyPlanUntil(format.formatDate(until.toLocal()))
        : l10n.companyPlanLapsed(format.formatDate(until.toLocal()));

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        Text(plan),
        const SizedBox(height: GarageTokens.space6),
        Text(
          l10n.companyDetailsHint,
          style: TextStyle(color: context.tokens.muted),
        ),
        const SizedBox(height: GarageTokens.space4),
        LabeledField(
          label: l10n.companyName,
          child: TextField(
            key: const Key('company-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        const SizedBox(height: GarageTokens.space4),
        LabeledField(
          label: l10n.companyOib,
          child: TextField(
            key: const Key('company-oib'),
            controller: _oib,
            keyboardType: TextInputType.number,
            // Eleven digits and nothing else can be typed, so the check on
            // save is left with the length alone to refuse.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GarageTheme.numericField(context),
          ),
        ),
        const SizedBox(height: GarageTokens.space4),
        LabeledField(
          label: l10n.companyAddress,
          child: TextField(
            key: const Key('company-address'),
            controller: _address,
            maxLines: 2,
          ),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: GarageTokens.space3),
          Text(error, style: TextStyle(color: context.tokens.danger)),
        ],
        const SizedBox(height: GarageTokens.space5),
        FilledButton(
          key: const Key('company-settings-save'),
          onPressed: _busy ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    String? trimmed(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final oib = trimmed(_oib);
    // The same rule the column holds, said here so the tab can name the
    // field rather than the database naming a constraint.
    if (oib != null && !RegExp(r'^[0-9]{11}$').hasMatch(oib)) {
      setState(() => _error = l10n.companyOibInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    // Through the settings controller, like every other household setting:
    // it patches the freshest household, serialises saves and refreshes the
    // household so the plan line and the fields read back what was saved.
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .save(
          (base) => base.copyWith(
            companyName: trimmed(_name),
            companyOib: oib,
            companyAddress: trimmed(_address),
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = failure == null ? null : failureMessage(l10n, failure);
    });
    if (failure == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.companyDetailsSaved)));
    }
  }
}
