import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/garage_bottom_nav.dart';
import '../../costs/cost_category_labels.dart';
import '../../income/income_category_labels.dart';
import '../../maintenance/service_type_labels.dart';
import '../../household/providers/member_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../fuel/widgets/fuel_entry_sheet.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../maintenance/widgets/service_entry_sheet.dart';
import '../../costs/providers/cost_providers.dart';
import '../../costs/widgets/cost_entry_sheet.dart';
import '../../odometer/providers/odometer_providers.dart';
import '../../odometer/widgets/odometer_entry_sheet.dart';
import '../../trips/providers/trip_providers.dart';
import '../../trips/widgets/trip_entry_sheet.dart';
import '../../income/providers/income_providers.dart';
import '../../income/widgets/income_entry_sheet.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/failure_message.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../providers/timeline_providers.dart';
import '../timeline_filter.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _search = TextEditingController();
  final Set<TimelineKind> _kinds = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Lets the six kinds be switched on and off, one row each.
  ///
  /// A sheet rather than chips on the screen: the labels are long in both
  /// languages, and a list gives each one a full line instead of squeezing six
  /// of them into the width of a phone.
  Future<void> _pickKinds() async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final kind in TimelineKind.values)
                CheckboxListTile(
                  key: Key('timeline-kind-${kind.name}'),
                  value: _kinds.contains(kind),
                  title: Text(_kindLabel(l10n, kind)),
                  onChanged: (on) {
                    // Both states: the sheet redraws its own tick, the screen
                    // refilters behind it.
                    setSheetState(() {});
                    setState(() {
                      on ?? false ? _kinds.add(kind) : _kinds.remove(kind);
                    });
                  },
                ),
              if (_kinds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(GarageTokens.space4),
                  child: TextButton(
                    onPressed: () {
                      setSheetState(() {});
                      setState(_kinds.clear);
                    },
                    child: Text(l10n.timelineFilterClear),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final vehicles = ref.watch(vehiclesProvider).value ?? const [];
    final vehicleNames = {for (final v in vehicles) v.id: v.nickname};
    // Who logged an entry is part of the record: a household can see who has
    // been keeping it up, and who paid for what. Via the provider rather than
    // rebuilt here — this screen had its own copy of the same comprehension,
    // which left `memberNamesProvider` looking unused and the two free to
    // disagree.
    final memberNames = ref.watch(memberNamesProvider).value ?? const {};
    // One query for the whole history; a row asking on its own behalf would be
    // a request per visible row. Empty while it loads, so the markers appear a
    // moment later rather than the list waiting on them.
    final withAttachments =
        ref.watch(entriesWithAttachmentsProvider).value ?? const <String>{};
    final monthFormat = DateFormat.yMMMM(locale);

    return GarageTabScaffold(
      current: GarageTab.timeline,
      // A ledger, not prose: each row anchors a title on the left and its
      // amount on the right, which is what a wide window is for. Splitting it
      // into columns would break the one thing it is sorted by, time.
      contentWidth: ContentWidth.wide,
      title: l10n.timelineTitle,
      body: AsyncValueView<List<TimelineItem>>(
        value: ref.watch(timelineProvider),
        onRetry: () => ref.invalidate(timelineProvider),
        empty: () => EmptyState(message: l10n.timelineEmpty),
        data: (all) {
          // The row's own rendered text is what a person is searching against:
          // they remember "the oil change on the Golf", not a service type key.
          String textOf(TimelineItem item) => [
            _titleOf(l10n, item),
            vehicleNames[item.vehicleId] ?? '',
            memberNames[item.createdBy] ?? '',
            format.formatShortDate(item.date),
            // The note too. It is often the only place the distinguishing
            // detail lives — which garage, which part, why this one was odd —
            // so searching everything except the free-text field misses the
            // thing the person actually wrote down.
            item.notes ?? '',
          ].join(' ');

          final items = filterTimeline(
            all,
            query: _search.text,
            kinds: _kinds,
            searchableText: textOf,
          );

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
                  memberName: memberNames[item.createdBy] ?? '',
                  format: format,
                  hasAttachment: withAttachments.contains(item.entryId),
                ),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GarageTokens.space4,
                  GarageTokens.space3,
                  GarageTokens.space4,
                  GarageTokens.space2,
                ),
                child: TextField(
                  key: const Key('timeline-search'),
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: l10n.timelineSearch,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_search.text.isNotEmpty)
                          IconButton(
                            tooltip: l10n.commonClear,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_search.clear),
                          ),
                        IconButton(
                          key: const Key('timeline-filter'),
                          tooltip: l10n.timelineFilter,
                          isSelected: _kinds.isNotEmpty,
                          icon: Badge.count(
                            count: _kinds.length,
                            isLabelVisible: _kinds.isNotEmpty,
                            child: const Icon(Icons.filter_list),
                          ),
                          onPressed: _pickKinds,
                        ),
                      ],
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              // The six kinds live behind the search field's filter button
              // rather than as a permanent block of chips.
              //
              // As a wrapped block they were honest but expensive: six chips
              // is two or three rows on a phone and three at a large text
              // size, all of it above the list, all of it spent on a filter
              // almost nobody has switched on. Folded away, an unfiltered
              // history costs nothing; a filtered one shows exactly the chips
              // that are on, so what is hiding rows is never a mystery.
              if (_kinds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    GarageTokens.space4,
                    0,
                    GarageTokens.space4,
                    GarageTokens.space2,
                  ),
                  child: Wrap(
                    spacing: GarageTokens.space2,
                    runSpacing: GarageTokens.space2,
                    children: [
                      for (final kind in _kinds)
                        InputChip(
                          key: Key('timeline-active-${kind.name}'),
                          label: Text(_kindLabel(l10n, kind)),
                          onDeleted: () => setState(() => _kinds.remove(kind)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: GarageTokens.space2),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(GarageTokens.space6),
                          child: Text(
                            l10n.timelineNoMatches,
                            style: TextStyle(color: context.tokens.muted),
                          ),
                        ),
                      )
                    : ListView(
                        key: const Key('timeline-list'),
                        padding: const EdgeInsets.only(
                          bottom: GarageTokens.space8,
                        ),
                        children: children,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({
    required this.item,
    required this.vehicleName,
    required this.memberName,
    required this.format,
    required this.hasAttachment,
  });

  final TimelineItem item;
  final String vehicleName;
  final String memberName;
  final UnitFormat format;

  /// Whether a receipt or document is kept with this entry.
  final bool hasAttachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final (IconData icon, String title) = switch (item.kind) {
      TimelineKind.fuel => (Icons.local_gas_station_outlined, l10n.fuelTitle),
      TimelineKind.service => (
        Icons.build_outlined,
        item.serviceTypeKeys
            .map((key) => serviceTypeLabel(l10n, key))
            .join(', '),
      ),
      TimelineKind.cost => (
        Icons.receipt_long_outlined,
        costCategoryLabel(l10n, item.costCategory ?? ''),
      ),
      TimelineKind.odometer => (Icons.speed_outlined, l10n.odometerTitle),
      TimelineKind.trip => (Icons.route_outlined, l10n.tripsTitle),
      TimelineKind.income => (
        Icons.savings_outlined,
        incomeCategoryLabel(l10n, item.costCategory ?? ''),
      ),
    };

    final details = [
      format.formatShortDate(item.date),
      vehicleName,
      if (item.distanceKm != null)
        format.formatDistance(item.distanceKm!, decimals: 0),
      if (item.odometerKm != null)
        format.formatDistance(item.odometerKm!.toDouble(), decimals: 0),
      memberName,
    ].where((part) => part.isNotEmpty).join(' · ');

    final hasNote = (item.notes ?? '').trim().isNotEmpty;

    // A note and a receipt were invisible from the list: the only way to learn
    // an entry had either was to open it, so the one row worth opening looked
    // exactly like the twenty that were not.
    final markers = <Widget>[
      if (hasNote)
        Icon(
          Icons.sticky_note_2_outlined,
          size: 16,
          color: context.tokens.muted,
          semanticLabel: l10n.timelineHasNote,
        ),
      if (hasAttachment)
        Icon(
          Icons.attach_file,
          size: 16,
          color: context.tokens.muted,
          semanticLabel: l10n.timelineHasAttachment,
        ),
    ];

    final amount = item.amount == null
        ? null
        : Text(
            // Money in is signed, because one column of unsigned amounts
            // would show a refund and a bill as the same thing.
            item.isIncome
                ? '+${format.formatMoney(item.amount)}'
                : format.formatMoney(item.amount),
            style: GarageTheme.numeric(
              Theme.of(context).textTheme.labelMedium!,
            ).copyWith(color: item.isIncome ? context.tokens.success : null),
          );

    return Card(
      child: ListTile(
        leading: Icon(icon, color: context.tokens.muted),
        title: Text(title),
        subtitle: Text(details),
        trailing: markers.isEmpty
            ? amount
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: GarageTokens.space2,
                children: [...markers, ?amount],
              ),
        onTap: () => _openEntry(context, ref, item),
      ),
    );
  }
}

/// The chip label for a kind — the plural noun a person would use for the
/// group, not the singular title a row carries.
String _kindLabel(AppLocalizations l10n, TimelineKind kind) {
  return switch (kind) {
    TimelineKind.fuel => l10n.fuelTitle,
    TimelineKind.service => l10n.maintenanceTitle,
    TimelineKind.cost => l10n.costsTitle,
    TimelineKind.odometer => l10n.odometerTitle,
    TimelineKind.trip => l10n.tripsTitle,
    TimelineKind.income => l10n.incomeTitle,
  };
}

/// What the row shows as its title, which is what a search should match.
String _titleOf(AppLocalizations l10n, TimelineItem item) {
  return switch (item.kind) {
    TimelineKind.fuel => l10n.fuelTitle,
    TimelineKind.service =>
      item.serviceTypeKeys.map((key) => serviceTypeLabel(l10n, key)).join(', '),
    TimelineKind.cost => costCategoryLabel(l10n, item.costCategory ?? ''),
    TimelineKind.odometer => l10n.odometerTitle,
    TimelineKind.trip => l10n.tripsTitle,
    TimelineKind.income => incomeCategoryLabel(l10n, item.costCategory ?? ''),
  };
}

/// Opens the entry a timeline row came from.
///
/// It used to push the *screen* the entry lives on — the fuel log, the vehicle
/// page — which made the app's only search surface answer "find that thing I
/// logged" with a list you have to search again. Three of the six kinds landed
/// on `/vehicles/:id`, which opens on Economy, not even the tab holding the
/// entry. Every sibling list already opens the sheet directly; this was the
/// exception.
Future<void> _openEntry(
  BuildContext context,
  WidgetRef ref,
  TimelineItem item,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final vehicleId = item.vehicleId;

  /// The first entry of a kind matching this row, or null.
  Future<T?> find<T>(Future<List<T>> entries, String Function(T) idOf) async {
    return (await entries).where((e) => idOf(e) == item.entryId).firstOrNull;
  }

  try {
    switch (item.kind) {
      case TimelineKind.fuel:
        final entry = await find(
          ref.read(rawFuelEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showFuelEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.service:
        final entry = await find(
          ref.read(serviceEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showServiceEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.cost:
        final entry = await find(
          ref.read(costEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showCostEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.odometer:
        final entry = await find(
          ref.read(odometerEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showOdometerEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.trip:
        final entry = await find(
          ref.read(tripEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showTripEntrySheet(context, vehicleId, existing: entry);
        }
      case TimelineKind.income:
        final entry = await find(
          ref.read(incomeEntriesProvider(vehicleId).future),
          (e) => e.id,
        );
        if (entry != null && context.mounted) {
          await showIncomeEntrySheet(context, vehicleId, existing: entry);
        }
    }
  } catch (error) {
    // A tap handler that throws tells the user nothing and reaches no screen.
    // Through failureMessage so the cause is recorded rather than dropped.
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
  }
}
