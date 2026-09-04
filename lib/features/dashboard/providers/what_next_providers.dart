import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_log.dart';

const _tourOpenedKey = 'what_next_tour_opened';
const _hiddenKey = 'what_next_hidden';

/// The two checklist facts the database cannot tell: whether the tour was
/// opened, and whether the card was put away. Both per device, like the
/// theme: a person who has read the tour on their phone has read it.
class WhatNextLocal {
  const WhatNextLocal({this.tourOpened = false, this.hidden = false});

  final bool tourOpened;
  final bool hidden;

  WhatNextLocal copyWith({bool? tourOpened, bool? hidden}) {
    return WhatNextLocal(
      tourOpened: tourOpened ?? this.tourOpened,
      hidden: hidden ?? this.hidden,
    );
  }
}

final whatNextLocalProvider =
    NotifierProvider<WhatNextLocalController, WhatNextLocal>(
      WhatNextLocalController.new,
    );

class WhatNextLocalController extends Notifier<WhatNextLocal> {
  @override
  WhatNextLocal build() {
    _load();
    return const WhatNextLocal();
  }

  /// The store, or null when the platform has none to give: the card then
  /// behaves as on a first run, which is the harmless direction, and the
  /// reason is on record rather than in a swallowed exception.
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on Object catch (error) {
      reportFailure(AppFailure.from(error));
      return null;
    }
  }

  Future<void> _load() async {
    final prefs = await _prefs();
    if (prefs == null) {
      return;
    }
    // Merged, not replaced: a tap that landed while the store was still
    // being read must not be undone by what the store said before it.
    state = WhatNextLocal(
      tourOpened: state.tourOpened || (prefs.getBool(_tourOpenedKey) ?? false),
      hidden: state.hidden || (prefs.getBool(_hiddenKey) ?? false),
    );
  }

  Future<void> markTourOpened() async {
    state = state.copyWith(tourOpened: true);
    await (await _prefs())?.setBool(_tourOpenedKey, true);
  }

  Future<void> hide() async {
    state = state.copyWith(hidden: true);
    await (await _prefs())?.setBool(_hiddenKey, true);
  }
}
