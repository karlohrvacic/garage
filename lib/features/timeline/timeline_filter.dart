import 'providers/timeline_providers.dart';

/// Narrows the history to what somebody is actually looking for.
///
/// Pure, and takes the searchable text as a callback rather than building it:
/// what a row *says* is a matter of localized labels — the service type, the
/// cost category, the vehicle's nickname, who logged it — and none of that
/// belongs in a filter. The screen knows how to render a row; this only knows
/// how to compare.
List<TimelineItem> filterTimeline(
  List<TimelineItem> items, {
  String query = '',
  Set<TimelineKind> kinds = const {},
  required String Function(TimelineItem item) searchableText,
}) {
  // An empty set means "everything", not "nothing". The alternative — starting
  // with all six selected — makes the chips read as six things you can switch
  // off rather than as a filter you can switch on, and leaves no state that
  // means "no filter".
  final matchesKind = kinds.isEmpty
      ? (TimelineItem _) => true
      : (TimelineItem item) => kinds.contains(item.kind);

  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  return items
      .where((item) {
        if (!matchesKind(item)) {
          return false;
        }
        if (terms.isEmpty) {
          return true;
        }
        // Every term has to appear somewhere, in any order: "golf oil" should find
        // an oil change on the Golf without the user guessing which word the app
        // wants first.
        final haystack = searchableText(item).toLowerCase();
        return terms.every(haystack.contains);
      })
      .toList(growable: false);
}
