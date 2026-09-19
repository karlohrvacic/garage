import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/company/money_entry.dart';
import '../../../domain/company/payment_method.dart';
import '../providers/company_providers.dart';

String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) {
  return switch (method) {
    PaymentMethod.companyCard => l10n.paidWithCompanyCard,
    PaymentMethod.companyCash => l10n.paidWithCompanyCash,
    PaymentMethod.ownMoney => l10n.paidWithOwnMoney,
  };
}

/// The word for where a money entry lives, in one place: the receipts
/// card and the accountant pack both name the kind beside the amount, and
/// two switches over the same three cases would drift.
String moneyEntryKindLabel(AppLocalizations l10n, MoneyEntryKind kind) {
  return switch (kind) {
    MoneyEntryKind.fuel => l10n.vehicleTabFuel,
    MoneyEntryKind.service => l10n.maintenanceTitle,
    MoneyEntryKind.cost => l10n.costsTitle,
  };
}

/// How a money entry was paid. Shown only in a garage on the plan: a
/// private garage has one pocket, and asking would be a field with one
/// possible answer.
class PaidWithField extends ConsumerWidget {
  const PaidWithField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final PaymentMethod? value;
  final ValueChanged<PaymentMethod?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(companyPlanProvider)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space3),
      child: LabeledField(
        label: l10n.companyPaidWith,
        child: DropdownButtonFormField<PaymentMethod?>(
          key: const Key('paid-with'),
          initialValue: value,
          isExpanded: true,
          items: [
            DropdownMenuItem<PaymentMethod?>(
              value: null,
              child: Text(l10n.paidWithNotRecorded),
            ),
            for (final method in PaymentMethod.values)
              DropdownMenuItem<PaymentMethod?>(
                value: method,
                child: Text(paymentMethodLabel(l10n, method)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
