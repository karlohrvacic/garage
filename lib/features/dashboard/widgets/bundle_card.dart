import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/maintenance/bundling.dart';
import '../../maintenance/service_type_labels.dart';

/// Suggests doing several nearby maintenance items in one shop visit.
///
/// Excluding an item rebuilds from [MaintenanceBundle.exclude], so the visit
/// date and span on screen always describe the items still in the group — the
/// original grouping's figures are never left standing after a change.
class BundleCard extends ConsumerStatefulWidget {
  const BundleCard({
    required this.bundle,
    this.vehicleNames = const {},
    super.key,
  });

  final MaintenanceBundle bundle;

  /// Vehicle id → display name, so items can be attributed. Optional: the card
  /// renders the service label alone when a name is not supplied.
  final Map<String, String> vehicleNames;

  @override
  ConsumerState<BundleCard> createState() => _BundleCardState();
}

class _BundleCardState extends ConsumerState<BundleCard> {
  /// Rules trimmed out of the suggestion on this screen, and nowhere else.
  ///
  /// Held as ids rather than by mutating the bundle so trimming can be undone.
  /// It could not be before: "Not this one" sat as a bare button beside every
  /// row, was easy to hit by accident, said nothing about what it did, and
  /// left no way back — while doing nothing at all to the underlying schedule,
  /// which is the part that made it alarming.
  final Set<String> _excluded = {};

  @override
  void didUpdateWidget(BundleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A freshly computed bundle (realtime change, another member logging a
    // service) starts the trimming over: the ids in it may no longer exist.
    if (widget.bundle != oldWidget.bundle) {
      _excluded.clear();
    }
  }

  MaintenanceBundle? get _current {
    var bundle = widget.bundle;
    for (final ruleId in _excluded) {
      final next = bundle.exclude(ruleId);
      if (next == null) {
        return null;
      }
      bundle = next;
    }
    return bundle;
  }

  void _exclude(String ruleId) => setState(() => _excluded.add(ruleId));

  void _putBack(String ruleId) => setState(() => _excluded.remove(ruleId));

  /// Opens a service entry with the bundled items already ticked.
  ///
  /// The whole point of the card is that these are happening together, and
  /// until now it said so and then left you to tick them off by hand on
  /// another screen. Only offered when the bundle is on one vehicle: a service
  /// entry belongs to a single car, and silently logging against the first of
  /// several would be worse than not offering it.
  Future<void> _logVisit(MaintenanceBundle bundle) async {
    final vehicleIds = bundle.items
        .map((item) => item.projection.vehicleId)
        .toSet();
    if (vehicleIds.length != 1) {
      return;
    }
    await showServiceEntrySheet(
      context,
      vehicleIds.single,
      initialServiceTypeKeys: {
        for (final item in bundle.items) item.projection.serviceTypeKey,
      },
    );
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
        padding: const EdgeInsets.all(GarageTokens.space4),
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
                    // An icon with a tooltip rather than a word: as a button
                    // labelled "Not this one" it read like a decision about
                    // the service itself, sitting a thumb's width from the
                    // item it would remove.
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: l10n.bundleExclude,
                      // Compact, because four of these at the default density
                      // are the tallest thing on the card and it sits above
                      // the list it is meant to introduce.
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _exclude(item.projection.ruleId),
                    ),
                  ],
                ),
              ),
            for (final ruleId in _excluded)
              Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _excludedLabel(l10n, ruleId),
                        style: TextStyle(
                          color: tokens.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _putBack(ruleId),
                      child: Text(l10n.bundlePutBack),
                    ),
                  ],
                ),
              ),
            // Only once something has been trimmed. Explaining an action
            // nobody has taken spent three lines of a dashboard card on a
            // reassurance nobody needed yet.
            if (_excluded.isNotEmpty)
              Text(
                l10n.bundleExcludeHint,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            const SizedBox(height: GarageTokens.space4),
            if (_singleVehicle(bundle))
              FilledButton.icon(
                key: const Key('bundle-log-visit'),
                onPressed: () => _logVisit(bundle),
                icon: const Icon(Icons.build_outlined),
                label: Text(l10n.bundleLogVisit),
              )
            else
              Text(
                l10n.bundleOneVehicleOnly,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
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

  bool _singleVehicle(MaintenanceBundle bundle) {
    return bundle.items
            .map((item) => item.projection.vehicleId)
            .toSet()
            .length ==
        1;
  }

  /// The label of a trimmed item, found in the original bundle since it is no
  /// longer in the current one.
  String _excludedLabel(AppLocalizations l10n, String ruleId) {
    for (final item in widget.bundle.items) {
      if (item.projection.ruleId == ruleId) {
        return _label(l10n, item);
      }
    }
    return ruleId;
  }
}
