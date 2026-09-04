import 'package:flutter/material.dart';

import '../../domain/format/month_grouping.dart';

/// A month-grouped log that builds only the rows in view.
///
/// Every log was a `ListView(children: [...])`, which builds every row of
/// the whole history on the first frame and keeps it in memory — fine for a
/// season, not for a household that imported years from Fuelio. This lays the
/// groups out as one flat index space (header, items, header, items) and
/// hands a builder to the list, so a row exists only while it is on screen.
///
/// [leading] and [trailing] are for the few widgets a log puts before or
/// after its months — a summary card, a balance footer. They are built
/// eagerly, which is what a handful of widgets can afford.
class LazyMonthList<T> extends StatelessWidget {
  const LazyMonthList({
    required this.groups,
    required this.header,
    required this.row,
    this.leading = const [],
    this.trailing = const [],
    this.padding,
    super.key,
  });

  final List<MonthGroup<T>> groups;
  final Widget Function(BuildContext context, MonthGroup<T> group) header;
  final Widget Function(BuildContext context, T item) row;
  final List<Widget> leading;
  final List<Widget> trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final slots = MonthGrouping.flatten(groups);
    return ListView.builder(
      padding: padding,
      itemCount: leading.length + slots.length + trailing.length,
      itemBuilder: (context, index) {
        if (index < leading.length) {
          return leading[index];
        }
        final slot = index - leading.length;
        if (slot < slots.length) {
          return switch (slots[slot]) {
            MonthHeaderSlot<T>(:final group) => header(context, group),
            MonthItemSlot<T>(:final item) => row(context, item),
          };
        }
        return trailing[slot - slots.length];
      },
    );
  }
}
