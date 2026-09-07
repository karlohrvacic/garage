import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../data/maintenance_repository.dart';
import '../providers/maintenance_providers.dart';
import '../service_type_labels.dart';

/// Choosing what a reminder, a service entry or a recorded spec is *about*.
///
/// Shared rather than copied: the reminder sheet had it first, and the sheet
/// that records what a car takes asks exactly the same question with the same
/// vocabulary. A second copy would have drifted the first time somebody added
/// a service type.
/// Types nobody schedules: they are logged after the fact on the service
/// sheet, and offered there, but not as reminders.
const oneOffServiceTypes = {'service_issue', 'service_modification'};

/// The handful a household sets first. Shown before the alphabet so the
/// third thing a new user does is not a scan of thirty rows for "Oil change".
/// Paid, not done: these are logged from the cost sheet, which also sets
/// their reminder. Two of them are not flagged statutory in the catalogue
/// (comprehensive insurance and a vignette are optional), so the flag alone
/// left them among the workshop jobs.
const paperworkServiceTypes = {
  'service_registration',
  'service_technical_inspection',
  'service_insurance',
  'service_insurance_comprehensive',
  'service_vignette',
  // Cover bought, not work done — and now also raised by a document's own
  // expiry rather than only by paying for one.
  'service_green_card',
};

/// Shared with the service sheet, whose chips lead with the same jobs.
const commonServiceTypes = [
  'service_oil_change',
  'service_registration',
  'service_insurance',
  'service_technical_inspection',
  'service_tire_swap_seasonal',
  'service_brake_pads_front',
];

/// The types a reminder may be set for: the catalogue minus what nobody
/// schedules, plus whatever type an existing rule already has.
///
/// A fault or a modification is logged once it has happened; as a reminder
/// it is a thing nobody schedules, and it sat between the brake parts and
/// the oil in a list already thirty long.
List<ServiceType> offeredReminderTypes(
  List<ServiceType> types,
  String? existingKey,
) {
  return [
    ...types.where(
      (type) =>
          !oneOffServiceTypes.contains(type.key) || type.key == existingKey,
    ),
    if (existingKey != null && !types.any((t) => t.key == existingKey))
      ServiceType(key: existingKey),
  ];
}

/// Reads like a dropdown, opens a sheet: a search box, the common items,
/// then everything else in order. A flat menu had no search and no order
/// but the alphabet.

class ServiceTypeField extends StatelessWidget {
  const ServiceTypeField({
    super.key,
    required this.selected,
    required this.vehicleId,
    required this.existingKey,
    required this.onChanged,
    this.fieldKey,
  });

  /// The key the tappable field carries. Two sheets open this picker and each
  /// has its own name for it in its own tests, so the shared widget does not
  /// own one of them.
  final Key? fieldKey;

  final String? selected;
  final String vehicleId;
  final String? existingKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      key: fieldKey,
      borderRadius: BorderRadius.circular(GarageTokens.radiusSm),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              ServiceTypeSheet(vehicleId: vehicleId, existingKey: existingKey),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selected == null
              ? l10n.serviceTypeChoose
              : serviceTypeLabel(l10n, selected!),
          style: selected == null
              ? TextStyle(color: context.tokens.muted)
              : null,
        ),
      ),
    );
  }
}

/// Watches the catalogue itself rather than taking a copy: opened a second
/// after the sheet on a cold load, a copy was the empty list the provider
/// had not yet filled, and "Nothing matches" blamed a query nobody had typed.
class ServiceTypeSheet extends ConsumerStatefulWidget {
  const ServiceTypeSheet({
    super.key,
    required this.vehicleId,
    required this.existingKey,
  });

  final String vehicleId;
  final String? existingKey;

  @override
  ConsumerState<ServiceTypeSheet> createState() => ServiceTypeSheetState();
}

class ServiceTypeSheetState extends ConsumerState<ServiceTypeSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalogue = ref.watch(
      availableServiceTypesProvider(widget.vehicleId),
    );
    final offered = offeredReminderTypes(
      catalogue.value ?? const [],
      widget.existingKey,
    );
    String label(ServiceType type) => serviceTypeLabel(l10n, type.key);
    bool matches(ServiceType type) =>
        _query.isEmpty || label(type).toLowerCase().contains(_query);

    final common = [
      for (final key in commonServiceTypes)
        for (final type in offered)
          if (type.key == key && matches(type)) type,
    ];
    final rest = [
      for (final type in offered)
        if (!commonServiceTypes.contains(type.key) && matches(type)) type,
    ]..sort((a, b) => label(a).compareTo(label(b)));

    Widget row(ServiceType type) => ListTile(
      title: Text(label(type)),
      onTap: () => Navigator.of(context).pop(type.key),
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space3,
        GarageTokens.space4,
        GarageTokens.space1,
      ),
      child: Text(text.toUpperCase(), style: GarageTheme.eyebrow(context)),
    );
    Widget note(String text) => Padding(
      padding: const EdgeInsets.all(GarageTokens.space4),
      child: Text(text, style: TextStyle(color: context.tokens.muted)),
    );

    final body = switch (catalogue) {
      AsyncValue(hasValue: false, isLoading: true) => const Padding(
        padding: EdgeInsets.all(GarageTokens.space6),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      AsyncValue(hasValue: false, error: final error?) => note(
        failureMessage(l10n, AppFailure.from(error)),
      ),
      _ => ListView(
        children: [
          if (common.isNotEmpty) ...[
            heading(l10n.serviceTypeCommon),
            for (final type in common) row(type),
          ],
          if (rest.isNotEmpty) ...[
            if (common.isNotEmpty) heading(l10n.serviceTypeOthers),
            for (final type in rest) row(type),
          ],
          if (common.isEmpty && rest.isEmpty) note(l10n.serviceTypeNoMatch),
        ],
      ),
    };

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(GarageTokens.space4),
                child: TextField(
                  key: const Key('service-type-search'),
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.serviceTypeSearch,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
