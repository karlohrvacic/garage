import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/stats/stats_section.dart';

const _hiddenSectionsKey = 'stats_hidden_sections';

/// Which parts of the statistics screen this reader has turned off.
///
/// Stored on the device rather than on the household: it is a display
/// preference like the theme, and one member hiding the station donut should
/// not hide it for everybody else in the household.
///
/// Hidden rather than visible is what is stored, so a section added in a later
/// release turns up for people who had already customised the screen instead of
/// being invisible to exactly the readers who care about this most.
final hiddenStatsSectionsProvider =
    NotifierProvider<HiddenStatsSections, Set<StatsSection>>(
      HiddenStatsSections.new,
    );

class HiddenStatsSections extends Notifier<Set<StatsSection>> {
  /// Completes once the stored choice has been read back. Nothing in the app
  /// awaits it — the screen simply rebuilds — but a test needs a point to wait
  /// for that is not a guessed number of event-loop turns.
  late Future<void> loaded;

  /// Whether this session has changed anything of its own. The read from
  /// storage is in flight while the screen is already usable, so a section
  /// switched off in that window would otherwise come straight back.
  bool _changed = false;

  @override
  Set<StatsSection> build() {
    loaded = _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getStringList(_hiddenSectionsKey);
    if (keys == null || _changed) {
      return;
    }
    state = {for (final key in keys) ?StatsSection.fromKey(key)};
  }

  bool isVisible(StatsSection section) => !state.contains(section);

  Future<void> setVisible(StatsSection section, bool visible) async {
    _changed = true;
    state = {
      for (final existing in StatsSection.values)
        if (existing == section ? !visible : state.contains(existing)) existing,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenSectionsKey, [
      for (final section in state) section.key,
    ]);
  }

  Future<void> showAll() async {
    _changed = true;
    state = const {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenSectionsKey);
  }
}
