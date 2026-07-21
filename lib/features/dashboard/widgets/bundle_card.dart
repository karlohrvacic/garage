import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/maintenance/bundling.dart';
import '../../maintenance/service_type_labels.dart';

/// Suggests doing several nearby maintenance items in one shop visit.
///
/// Excluding an item rebuilds from [MaintenanceBundle.exclude], so the visit
/// date and span on screen always describe the items still in the group — the
/// original grouping's figures are never left standing after a change.
class BundleCard extends StatefulWidget {
  const BundleCard({required this.bundle, this.vehicleNames = const {}, super.key});

  final MaintenanceBundle bundle;

  /// Vehicle id → display name, so items can be attributed. Optional: the card
  /// renders the service label alone when a name is not supplied.
  final Map<String, String> vehicleNames;

  @override
  State<BundleCard> createState() => _BundleCardState();
}

class _BundleCardState extends State<BundleCard> {
  MaintenanceBundle? _current;

  @override
  void initState() {
    super.initState();
    _current = widget.bundle;
  }

  void _exclude(String ruleId) {
    setState(() => _current = _current?.exclude(ruleId));
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _current;
    if (bundle == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final dateFormat = MaterialLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.bundleSuggestionTitle(bundle.items.length),
              style: theme.textTheme.titleLarge?.copyWith(color: tokens.accent),
            ),
            const SizedBox(height: GarageTokens.space1),
            Text(
              l10n.bundleVisitOn(dateFormat.formatShortDate(bundle.visitDate)),
              style: GarageTheme.numeric(theme.textTheme.bodyMedium!),
            ),
            Text(
              l10n.bundleSpanDays(bundle.span.inDays),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space3),
            Text(
              l10n.bundleExplain,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space4),
            for (final item in bundle.items)
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                child: Row(
                  children: [
                    Expanded(child: Text(_label(l10n, item))),
                    TextButton(
                      onPressed: () => _exclude(item.projection.ruleId),
                      child: Text(l10n.bundleExclude),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, BundleItem item) {
    final service = serviceTypeLabel(l10n, item.projection.serviceTypeKey);
    final name = widget.vehicleNames[item.projection.vehicleId];
    return name == null ? service : '$name · $service';
  }
}
