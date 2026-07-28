import 'package:flutter/material.dart';

/// Width thresholds shared by every surface that adapts between phone and
/// desktop presentation.
abstract final class GarageBreakpoints {
  /// At and above this window width the app drops phone chrome (bottom bar,
  /// edge-to-edge lists, bottom sheets) for desktop chrome (rail, capped
  /// column, dialogs).
  static const double wide = 900;

  /// Content column cap on wide screens.
  static const double contentMaxWidth = 840;

  /// Entry-form dialog cap on wide screens.
  static const double dialogMaxWidth = 480;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}

/// Centers and caps its child on wide screens; transparent on phones. Wrap a
/// pushed screen's body so desktop windows don't stretch lists edge to edge.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!GarageBreakpoints.isWide(context)) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: GarageBreakpoints.contentMaxWidth,
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
