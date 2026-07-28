import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../costs/cost_category_labels.dart';
import '../../maintenance/service_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/timeline_providers.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final vehicleNames = {for (final v in vehicles) v.id: v.nickname};
    final monthFormat = DateFormat.yMMMM(locale);

    return GarageTabScaffold(
      current: GarageTab.timeline,
      appBar: AppBar(title: Text(l10n.timelineTitle)),
      body: AsyncValueView<List<TimelineItem>>(
        value: ref.watch(timelineProvider),
        onRetry: () => ref.invalidate(timelineProvider),
        empty: () => EmptyState(message: l10n.timelineEmpty),
        data: (items) {
          final children = <Widget>[];
          DateTime? currentMonth;
          for (final item in items) {
            final month = DateTime.utc(item.date.year, item.date.month);
            if (currentMonth == null || month != currentMonth) {
              currentMonth = month;
              children.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    GarageTokens.space4,
                    GarageTokens.space4,
                    GarageTokens.space2,
                  ),
                  child: Text(
                    monthFormat.format(month).toUpperCase(),
                    style: GarageTheme.eyebrow(context),
                  ),
                ),
              );
            }
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GarageTokens.space4,
                  vertical: GarageTokens.space1,
                ),
                child: _TimelineRow(
                  item: item,
                  vehicleName: vehicleNames[item.vehicleId] ?? '',
                  format: format,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: GarageTokens.space8),
            children: children,
          );
        },
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.vehicleName,
    required this.format,
  });

  final TimelineItem item;
  final String vehicleName;
  final UnitFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final (IconData icon, String title, String route) = switch (item.kind) {
      TimelineKind.fuel => (
        Icons.local_gas_station_outlined,
        l10n.fuelTitle,
        '/vehicles/${item.vehicleId}/fuel',
      ),
      TimelineKind.service => (
        Icons.build_outlined,
        item.serviceTypeKeys
            .map((key) => serviceTypeLabel(l10n, key))
            .join(', '),
        '/vehicles/${item.vehicleId}/maintenance',
      ),
      TimelineKind.cost => (
        Icons.receipt_long_outlined,
        costCategoryLabel(l10n, item.costCategory ?? ''),
        '/vehicles/${item.vehicleId}',
      ),
    };

    final details = [
      format.formatShortDate(item.date),
      vehicleName,
      if (item.odometerKm != null)
        format.formatDistance(item.odometerKm!.toDouble(), decimals: 0),
    ].where((part) => part.isNotEmpty).join(' · ');

    return Card(
      child: ListTile(
        leading: Icon(icon, color: context.tokens.muted),
        title: Text(title),
        subtitle: Text(details),
        trailing: item.amount == null
            ? null
            : Text(
                format.formatMoney(item.amount),
                style: GarageTheme.numeric(
                  Theme.of(context).textTheme.labelMedium!,
                ),
              ),
        onTap: () => context.push(route),
      ),
    );
  }
}
