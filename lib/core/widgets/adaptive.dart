import 'package:flutter/material.dart';

/// Width thresholds shared by every surface that adapts between phone and
/// desktop presentation.
abstract final class GarageBreakpoints {
  /// At and above this window width the app drops phone chrome (bottom bar,
  /// edge-to-edge lists, bottom sheets) for desktop chrome (rail, capped
  /// column, dialogs).
  static const double wide = 900;

  /// At and above this width the rail carries labels and the shell reads as a
  /// desktop application rather than a phone app in a column.
  static const double desktop = 1200;

  /// Reading-width cap. A form or a column of prose stretched across a monitor
  /// is harder to read, not easier, so this stays narrow on purpose.
  static const double contentMaxWidth = 840;

  /// Cap for content that genuinely uses width: dashboards, grids, tables.
  /// Still capped, because cards spread across an ultrawide are no better
  /// than a narrow column, only differently wrong.
  static const double wideContentMaxWidth = 1440;

  /// Entry-form dialog cap on wide screens.
  static const double dialogMaxWidth = 480;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

/// How much width a screen's content wants.
///
/// One global cap cannot serve both: 840 is right for an entry form and wrong
/// for a dashboard, which was why every desktop window looked like a phone.
enum ContentWidth {
  /// Forms, settings, prose. Capped for legibility.
  reading,

  /// Dashboards, grids, lists that benefit from columns.
  wide,
}

/// Centers and caps its child on wide screens; transparent on phones. Wrap a
/// pushed screen's body so desktop windows don't stretch lists edge to edge.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    super.key,
    required this.child,
    this.width = ContentWidth.reading,
  });

  final Widget child;

  /// Defaults to reading width: a screen has to ask for the extra room, so a
  /// form never accidentally sprawls because someone added a wrapper.
  final ContentWidth width;

  @override
  Widget build(BuildContext context) {
    if (!GarageBreakpoints.isWide(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: switch (width) {
            ContentWidth.reading => GarageBreakpoints.contentMaxWidth,
            ContentWidth.wide => GarageBreakpoints.wideContentMaxWidth,
          },
        ),
        child: child,
      ),
    );
  }
}

/// Entry forms present as bottom sheets on phones and as centered dialogs on
/// desktop-width windows, where a sheet sliding across the whole monitor reads
/// as misplaced phone UI.
Future<T?> showAdaptiveEntrySheet<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  if (!GarageBreakpoints.isWide(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: GarageBreakpoints.dialogMaxWidth,
        ),
        child: builder(dialogContext),
      ),
    ),
  );
}

/// Lays its children in two columns on a desktop window and one on anything
/// narrower.
///
/// Sections alternate between the columns rather than filling the first and
/// then the second, so both sides carry content instead of leaving a long left
/// column beside a short right one. This is not a masonry layout: it does not
/// measure heights, which keeps it cheap and predictable, at the cost of the
/// two columns rarely ending level.
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({super.key, required this.children, this.spacing});

  final List<Widget> children;

  /// Gap between the columns. Defaults to the standard section spacing.
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    if (!GarageBreakpoints.isDesktop(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: left,
          ),
        ),
        SizedBox(width: spacing ?? 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: right,
          ),
        ),
      ],
    );
  }
}
